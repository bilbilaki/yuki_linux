import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_linux_webview/flutter_linux_webview.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:ui';
import 'package:yuki/ai.dart'; // Make sure your AI code is in this file

// IMPORTANT: Add your OpenAI API key here
import 'package:yuki/controller.dart';

void main() {

  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    WebView.platform = SurfaceAndroidWebView();
  } else{ LinuxWebViewPlugin.initialize(); 
  WebView.platform = LinuxWebView();}
  runApp(const MaterialApp(home: AdvancedWebViewer()));
}

class AdvancedWebViewer extends StatefulWidget {
  const AdvancedWebViewer({Key? key}) : super(key: key);

  @override
  _AdvancedWebViewerState createState() => _AdvancedWebViewerState();
}

class _AdvancedWebViewerState extends State<AdvancedWebViewer> with WidgetsBindingObserver {
  late final WebViewController _webViewController;
  late final AssistantService _assistantService;
  final TextEditingController _promptController = TextEditingController();
  final List<String> _chatMessages = [];
  bool _isAssistantProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _addChatMessage(String message) {
    setState(() {
      _chatMessages.insert(0, message); // Add to the top of the list
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await LinuxWebViewPlugin.terminate();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Web Assistant'),
        backgroundColor: Colors.blueGrey[800],
      ),
      body: Column(
        children: [
          // The WebView
          Expanded(
            flex: 3, // Takes 3/5 of the screen
            child: WebView(
              initialUrl: 'https://duckduckgo.com/',
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController controller) {
                _webViewController = controller;
                // Initialize the assistant service once the webview is ready
                _assistantService = AssistantService(
                  webViewAIController: WebViewAIController(_webViewController),
                  onNewMessage: (message) {
                    _addChatMessage(message);
                  },
                );
              },
            ),
          ),
          // The Chat/Control Panel
          Expanded(
            flex: 2, // Takes 2/5 of the screen
            child: Container(
              color: Colors.grey[200],
              child: Column(
                children: [
                  // Chat history
                  Expanded(
                    child: ListView.builder(
                      reverse: true, // Show latest messages first
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final message = _chatMessages[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: message.startsWith("User:") ? Colors.blue[100] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(message),
                        );
                      },
                    ),
                  ),
                  // Input field
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promptController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., "search for cute cat pictures"',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: _isAssistantProcessing ? null : _handleSubmitted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isAssistantProcessing
                            ? const CircularProgressIndicator()
                            : IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: () => _handleSubmitted(_promptController.text),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    final prompt = text;
    _promptController.clear();
    setState(() {
      _isAssistantProcessing = true;
    });

    try {
      await _assistantService.processUserPrompt(prompt);
    } catch (e) {
      _addChatMessage("An error occurred: $e");
    } finally {
      setState(() {
        _isAssistantProcessing = false;
      });
    }
  }
}