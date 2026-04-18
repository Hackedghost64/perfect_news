import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ReaderView extends StatefulWidget {
  final String url;
  final String sourceName;

  const ReaderView({super.key, required this.url, required this.sourceName});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _injectBrutalistTheme();
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // The Hostile CSS Injection
  void _injectBrutalistTheme() {
    const String css = """
      var style = document.createElement('style');
      style.innerHTML = '
        * { 
          background-color: #000000 !important; 
          color: #FFFFFF !important; 
          font-family: monospace !important; 
        } 
        /* Nuke ads, videos, and images */
        iframe, img, video, canvas, figure, .ad, [class*="ad-"], [id*="ad-"] { 
          display: none !important; 
        }
      ';
      document.head.appendChild(style);
    """;

    // Clean up formatting for JS evaluation
    final cleanJs = css.replaceAll('\n', '').replaceAll(RegExp(r'\s+'), ' ');

    _controller.runJavaScript(cleanJs).catchError((e) {
      debugPrint("WARN: JS Injection blocked by source -> $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.sourceName.toUpperCase(),
          style: const TextStyle(letterSpacing: 2.0),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}
