import os
import json
import logging
import time
from datetime import datetime, timezone
from time import mktime
import feedparser
import firebase_admin
from firebase_admin import credentials, messaging

# ---------------------------------------------------------
# Trace Debugging: Professional Logging Setup
# ---------------------------------------------------------
logging.basicConfig(
    level=logging.INFO, 
    format='[%(levelname)s] %(asctime)s - %(message)s'
)

class ConfigLoader:
    def __init__(self, config_path="sources.json"):
        self.config_path = config_path

    def load(self):
        try:
            with open(self.config_path, 'r') as file:
                sources = json.load(file)
                logging.info(f"Loaded {len(sources)} sources from config.")
                return sources
        except FileNotFoundError:
            logging.error(f"CRITICAL: {self.config_path} not found.")
            # Fail-fast: If there's no config, the script must die.
            assert False, "Config file missing." 

class StateCache:
    def __init__(self, cache_file="last_run_time.txt"):
        self.cache_file = cache_file

    def get_last_run(self):
        try:
            with open(self.cache_file, 'r') as file:
                return float(file.read().strip())
        except (FileNotFoundError, ValueError):
            logging.warning("No valid cache found. Defaulting to current time minus 1 hour.")
            return time.time() - 3600

    def update_last_run(self, current_time):
        with open(self.cache_file, 'w') as file:
            file.write(str(current_time))
        logging.info("StateCache updated.")

class RSSManager:
    def __init__(self, sources, last_run_time):
        self.sources = sources
        self.last_run_time = last_run_time

    def fetch_new_articles(self):
        new_articles = []
        for source in self.sources:
            logging.info(f"Fetching: {source['name']} ({source['url']})")
            try:
                feed = feedparser.parse(source['url'])
                
                # Defensive Programming: Check if the feed is valid
                if feed.bozo:
                    logging.error(f"Malformed XML from {source['name']}. Skipping.")
                    continue

                for entry in feed.entries:
                    # Convert RSS time struct to Unix timestamp
                    if hasattr(entry, 'published_parsed'):
                        article_time = mktime(entry.published_parsed)
                        if article_time > self.last_run_time:
                            new_articles.append({
                                'title': entry.title,
                                'source': source['name'],
                                'url': entry.link
                            })
            except Exception as e:
                logging.error(f"Failed to fetch {source['name']}: {str(e)}")
                
        return new_articles

class NotificationDispatcher:
    def __init__(self):
        # Securely load credentials from GitHub Secrets environment variable
        cred_json_str = os.environ.get("FIREBASE_CREDENTIALS")
        assert cred_json_str is not None, "CRITICAL: FIREBASE_CREDENTIALS environment variable is missing."
        
        try:
            cred_dict = json.loads(cred_json_str)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            logging.info("Firebase authenticated successfully via secure environment variable.")
        except Exception as e:
            logging.error(f"Failed to parse Firebase credentials: {str(e)}")
            assert False, "Firebase init failed."

    def broadcast(self, article):
        # We broadcast to a single FCM topic (e.g., 'breaking_news') 
        # that all Flutter app installations will subscribe to.
        message = messaging.Message(
            notification=messaging.Notification(
                title=f"WIRE: {article['source']}",
                body=article['title'],
            ),
            topic='breaking_news',
        )
        try:
            response = messaging.send(message)
            logging.info(f"FCM Push Success: {response} - {article['title']}")
        except Exception as e:
            logging.error(f"FCM Push Failed: {str(e)}")

# ---------------------------------------------------------
# Execution (Main Logic Flow)
# ---------------------------------------------------------
if __name__ == "__main__":
    current_time = time.time()
    
    loader = ConfigLoader()
    sources = loader.load()
    
    cache = StateCache()
    last_run = cache.get_last_run()
    
    manager = RSSManager(sources, last_run)
    new_articles = manager.fetch_new_articles()
    
    if new_articles:
        logging.info(f"Found {len(new_articles)} new articles. Dispatching...")
        dispatcher = NotificationDispatcher()
        
        # To avoid spamming, only send the top 3 newest articles max in one run
        for article in new_articles[:3]:
            dispatcher.broadcast(article)
    else:
        logging.info("No new articles found.")
        
    cache.update_last_run(current_time)
