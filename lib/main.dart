import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:ui';

void main() {

  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MaterialApp(home: AdvancedWebViewer()));
}

class AdvancedWebViewer extends StatefulWidget {
  const AdvancedWebViewer({Key? key}) : super(key: key);

  @override
  State<AdvancedWebViewer> createState() => _AdvancedWebViewerState();
}

class _AdvancedWebViewerState extends State<AdvancedWebViewer> with WidgetsBindingObserver {
  // All state and controllers now live here
  late final WebViewController _webViewController;
  late final AssistantService _assistantService;
  var loadingPercentage = 0;

  final TextEditingController _promptController = TextEditingController();
  final List<String> _chatMessages = [];
  bool _isAssistantProcessing = false;

 @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // CORRECT: Initialize the controller here in the parent widget's initState
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // ESSENTIAL for your JS tools
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            loadingPercentage = 0;
          });
        },
        onProgress: (progress) {
          setState(() {
            loadingPercentage = progress;
          });
        },
        onPageFinished: (url) {
          setState(() {
            loadingPercentage = 100;
          });
        },
        onWebResourceError: (error) {
           // Handle errors, e.g., show a snackbar
          debugPrint('''
            Page resource error:
            code: ${error.errorCode}
            description: ${error.description}
            errorType: ${error.errorType}
            isForMainFrame: ${error.isForMainFrame}
          ''');
        },
      ))
      ..loadRequest(
        // Start with a known page
        Uri.parse('https://duckduckgo.com/'),
      );

    // Initialize the assistant service with the now-ready controller
    _assistantService = AssistantService(
      webViewAIController: WebViewAIController(_webViewController),
      onNewMessage: (message) {
        _addChatMessage(message);
      },
    );
  
  }


  void _addChatMessage(String message) {
    setState(() {
      _chatMessages.insert(0, message); // Add to the top of the list
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _promptController.dispose();
    super.dispose();
  }


  @override
  Future<AppExitResponse> didRequestAppExit() async {
    // You can add logic here to ask the user for confirmation
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Web Assistant'),
        backgroundColor: Colors.blueGrey[800],
        actions: [
          // The controller is now correctly initialized before being used here
          NavigationControls(controller: _webViewController),
        ],
      ),
      // CORRECTED LAYOUT: Use a Column to separate WebView and Chat UI
      body: Column(
        children: [
          // The WebView area
          Expanded(
            flex: 3, // Takes 3/5 of the screen
            child: WebViewStack(
              controller: _webViewController,
              loadingPercentage: loadingPercentage,
            ),
          ),
          // The Chat UI area
          Expanded(
            flex: 2, // Takes 2/5 of the screen
            child: Container(
              color: Colors.grey[200],
              child: Column(
                children: [
                  // Chat history
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final message = _chatMessages[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: message.startsWith("User:") ? Colors.blue[100] : (message.startsWith("🤖") ? Colors.green[100] : Colors.white),
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
                        if (_isAssistantProcessing)
                          const CircularProgressIndicator()
                        else
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () => _handleSubmitted(_promptController.text),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    final prompt = text;
    _promptController.clear();
    _addChatMessage("User: $prompt"); // Show user's prompt immediately
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

// SIMPLIFIED WIDGET: This widget now only displays the webview and progress bar.
// It receives all its data from the parent.
class WebViewStack extends StatelessWidget {
  const WebViewStack({
    required this.controller,
    required this.loadingPercentage,
    super.key,
  });

  final WebViewController controller;
  final int loadingPercentage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(
          controller: controller,
        ),
        if (loadingPercentage < 100)
          LinearProgressIndicator(
            value: loadingPercentage / 100.0,
          ),
      ],
    );
  }
}

class NavigationControls extends StatelessWidget {
  const NavigationControls({required this.controller, super.key});

  final WebViewController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (await controller.canGoBack()) {
              await controller.goBack();
            } else {
              messenger.showSnackBar(
                const SnackBar(content: Text('No back history item')),
              );
              return;
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (await controller.canGoForward()) {
              await controller.goForward();
            } else {
              messenger.showSnackBar(
                const SnackBar(content: Text('No forward history item')),
              );
              return;
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.replay),
          onPressed: () {
            controller.reload();
          },
        ),
      ],
    );
  }
}
class WebViewAIController {
  final WebViewController controller;

  WebViewAIController(this.controller);

  /// Navigates to a specific URL.
  Future<String> loadUrl(String url) async {
    try {
      await controller.loadRequest(
        Uri.parse(url));
      // It's better to wait for the page to finish loading.
      // This is a simplification; a full solution would use onPageFinished callback.
      await Future.delayed(const Duration(seconds: 3)); 
      final currentUrl = await controller.currentUrl();
      if (currentUrl != null && currentUrl.contains(url)) {
        return "Successfully loaded URL: $url";
      } else {
        return "Failed to load URL: $url. Current URL is $currentUrl";
      }
    } catch (e) {
      return "Error loading URL: $e";
    }
  }


  Future<String> typeInElement(String selector, String text) async {
    final escapedText = jsonEncode(text);

    final js = """
      (function() {
        try {
          const element = document.querySelector('$selector');
          if (element) {
            element.value = $escapedText;
            // This event is important for some frameworks (like React) to recognize the change
            element.dispatchEvent(new Event('input', { bubbles: true }));
            return 'Successfully typed "$text" into element with selector "$selector".';
          } else {
            return 'Error: Element with selector "$selector" not found.';
          }
        } catch (e) {
          return 'Error executing script for typing: ' + e.message;
        }
      })();
    """;
    final result = await controller.runJavaScriptReturningResult(js);
    return result.toString().replaceAll('"', ''); // Also good to sanitize quotes
  }

  /// Clicks an element found by a CSS selector.
  Future<String> clickElement(String selector) async {
    //
    // Notice the new (function() { ... })(); wrapper
    //
    final js = """
      (function() {
        try {
          const element = document.querySelector('$selector');
          if (element) {
            element.click();
            return 'Successfully clicked element with selector "$selector".';
          } else {
            return 'Error: Element with selector "$selector" not found.';
          }
        } catch (e) {
          return 'Error executing script for clicking: ' + e.message;
        }
      })();
    """;
    final result = await controller.runJavaScriptReturningResult(js);
    return result.toString().replaceAll('"', '');
  }

  /// Reads the visible text content of the entire page or a specific element.
  Future<String> readTextContent({String? selector}) async {
    final target = selector != null ? "document.querySelector('$selector')" : "document.body";
    //
    // Notice the new (function() { ... })(); wrapper
    //
    final js = """
      (function() {
        try {
          const element = $target;
          if (element) {
            // Limit the text length to avoid overflowing the AI's context window
            let text = element.innerText || element.textContent;
            return text.trim().substring(0, 4000);
          } else {
            return 'Error: Element with selector "$selector" not found.';
          }
        } catch (e) {
          return 'Error reading content: ' + e.message;
        }
      })();
    """;
    final result = await controller.runJavaScriptReturningResult(js);
    return result.toString().replaceAll('"', '').trim();
  }
  Future<String> getInteractiveElements() async {
 const js = r"""
    (function() {
        const elements = document.querySelectorAll('a, button, input, textarea, select, [role="button"], [role="link"]');
        const visibleElements = [];
        let idCounter = 1;

        elements.forEach(el => {
            const rect = el.getBoundingClientRect();
            // Check if element is visible in the viewport
            if (rect.width > 0 && rect.height > 0 && rect.top < window.innerHeight && rect.bottom > 0 && rect.left < window.innerWidth && rect.right > 0) {
                // Assign a temporary ID for this run
                const aiId = `ai-id-${idCounter++}`;
                el.setAttribute('data-ai-id', aiId);

                let description = el.getAttribute('aria-label') || el.textContent.trim() || el.value || el.placeholder || el.name || 'no description';
                description = description.replace(/\s+/g, ' ').substring(0, 100);

                visibleElements.push({
                    id: aiId,
                    tagName: el.tagName.toLowerCase(),
                    description: description
                });
            }
        });
        return JSON.stringify(visibleElements);
    })();
  """;
  final result = await controller.runJavaScriptReturningResult(js);
  return result.toString();

}

// We also need ID-based versions of click and type
Future<String> clickElementByAiId(String aiId) async {
  final js = """
    (function() {
      const el = document.querySelector(`[data-ai-id="${aiId}"]`);
      if (el) { el.click(); return `Clicked element with id ${aiId}`; }
      return `Error: Element with id ${aiId} not found.`;
    })();
  """;
  return (await controller.runJavaScriptReturningResult(js)).toString();
}

Future<String> typeInElementByAiId(String aiId, String text) async {
  final escapedText = jsonEncode(text);
  final js = """
    (function() {
      const el = document.querySelector(`[data-ai-id="${aiId}"]`);
      if (el) {
        el.value = $escapedText;
        el.dispatchEvent(new Event('input', { bubbles: true }));
        return `Typed into element with id ${aiId}`;
      }
      return `Error: Element with id ${aiId} not found.`;
    })();
  """;
  return (await controller.runJavaScriptReturningResult(js)).toString();
}
}



const loadUrlTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: 'loadUrl',
    description: 'Navigates the web browser to a specific URL.',
    parameters: {
      'type': 'object',
      'properties': {
        'url': {
          'type': 'string',
          'description': 'The full URL to load, including https://',
        },
      },
      'required': ['url'],
    },
  ),
);

const typeInElementTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: 'typeInElement',
    description: 'Types text into an input field, textarea, or other editable element on the page.',
    parameters: {
      'type': 'object',
      'properties': {
        'selector': {
          'type': 'string',
          'description': 'A CSS selector to find the target element (e.g., "#search", "input[name=\'q\']").',
        },
        'text': {
          'type': 'string',
          'description': 'The text to type into the element.',
        },
      },
      'required': ['selector', 'text'],
    },
  ),
);

const clickElementTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: 'clickElement',
    description: 'Clicks a button, link, or any other clickable element on the page.',
    parameters: {
      'type': 'object',
      'properties': {
        'selector': {
          'type': 'string',
          'description': 'A CSS selector to find the clickable element (e.g., "button[type=\'submit\']", "#login-btn").',
        },
      },
      'required': ['selector'],
    },
  ),
);

const readTextContentTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: 'readTextContent',
    description: 'Reads the visible text from the page. Use this to understand the page content, find information, or confirm an action was successful. Can be used on the whole page or a specific element.',
    parameters: {
      'type': 'object',
      'properties': {
        'selector': {
          'type': 'string',
          'description': '(Optional) A CSS selector to read text from a specific element instead of the whole page.',
        },
      },
      'required': [],
    },
  ),
);
const getInteractiveElementsTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: 'getInteractiveElements',
    description: 'Scans the current webpage and returns a JSON list of all visible, interactive elements (links, buttons, inputs). Call this first to understand what is on the page.',
    parameters: {'type': 'object', 'properties': {}},
  ),
);

// MODIFIED ACTION TOOLS
const typeInElementByIdTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: 'typeInElementByAiId',
    description: 'Types text into an element using the ID from getInteractiveElements.',
    parameters: {
      'type': 'object',
      'properties': {
        'aiId': {'type': 'string', 'description': 'The data-ai-id of the target element.'},
        'text': {'type': 'string', 'description': 'The text to type.'},
      },
      'required': ['aiId', 'text'],
    },
  ),
);

const clickElementByIdTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: 'clickElementByAiId',
    description: 'Clicks an element using the ID from getInteractiveElements.',
    parameters: {
      'type': 'object',
      'properties': {
        'aiId': {'type': 'string', 'description': 'The data-ai-id of the target element.'},
      },
      'required': ['aiId'],
    },
  ),
);

// Keep loadUrl and readTextContent as they are useful.

// List of all available tools
final List<ChatCompletionTool> allTools = [
  loadUrlTool,
  typeInElementTool,
  getInteractiveElementsTool, // The new "vision" tool
  typeInElementByIdTool,      // The new ID-based typing tool
  clickElementByIdTool,   
  clickElementTool,
  readTextContentTool,
];
final client = OpenAIClient(
  apiKey:'aa-Ag0FkYecrGW214FK0YV8XFMwyVnadVUT1wZt3R1Q360lAOwa',
  baseUrl: 'https://api.avalai.org/v1',
);


class AssistantService {
  final WebViewAIController webViewAIController;
  final Function(String message) onNewMessage; // Callback to update UI

  // This holds the entire conversation history
  final List<ChatCompletionMessage> _messages = [];

  AssistantService({required this.webViewAIController, required this.onNewMessage}) {
    // Start with a system prompt that defines the AI's role and rules.
    _messages.add(
  ChatCompletionMessage.system(
    content: """
    You are an advanced web browsing assistant.
    Your goal is to help the user accomplish tasks on the web.
    You operate in a strict loop: SEE, DECIDE, ACT.

    1. **SEE**: ALWAYS start by using the `getInteractiveElements` tool to see what is on the page. This gives you a list of elements and their IDs.
    2. **DECIDE**: Based on the user's request and the list of elements, decide what to do next. If you need to type, find the correct input element's ID. If you need to click, find the correct button or link's ID.
    3. **ACT**: Use the `typeInElementByAiId` or `clickElementByAiId` tools with the ID you chose.
    4. **CONFIRM**: After an action, you can use `readTextContent` to see the result of your action or call `getInteractiveElements` again to see how the page has changed.
    5. **RESPOND**: When the task is fully complete, provide a final, concise answer to the user. Do not mention your tools or IDs in the final answer.
    """,
  ),
);}

  Future<void> processUserPrompt(String prompt) async {
    onNewMessage("User: $prompt");
    _messages.add(ChatCompletionMessage.user(content: ChatCompletionUserMessageContent.string(prompt)));

    // Start the agent loop
    while (true) {
      final res = await client.createChatCompletion( request: CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId('gpt-4o-mini'),
        messages: _messages,
        tools: allTools,
        toolChoice: ChatCompletionToolChoiceOption.mode(ChatCompletionToolChoiceMode.auto),
      )
      );
      final choice = res.choices.first;
      final message = choice.message;

      // Add the AI's response to history (whether it's a tool call or text)
      _messages.add(message);

      if (message.toolCalls == null || message.toolCalls!.isEmpty) {
        // The AI has finished and is giving a final text response.
        onNewMessage("Assistant: ${message.content}");
        break; // Exit the loop
      }

      // The AI wants to use one or more tools.
      for (final toolCall in message.toolCalls!) {
        final functionCall = toolCall.function;
        final arguments = json.decode(functionCall.arguments) as Map<String, dynamic>;
        
        onNewMessage("🤖 Calling tool: ${functionCall.name} with args: $arguments");

        // --- The Tool Dispatcher ---
        String functionResult;
        switch (functionCall.name) {
          case 'loadUrl':
            functionResult = await webViewAIController.loadUrl(arguments['url']);
            break;
          case 'typeInElement':
            functionResult = await webViewAIController.typeInElement(arguments['selector'], arguments['text']);
            break;
          case 'clickElement':
            functionResult = await webViewAIController.clickElement(arguments['selector']);
            break;
          case 'readTextContent':
            functionResult = await webViewAIController.readTextContent(selector: arguments['selector']);
            break;
          default:
            functionResult = "Error: Unknown tool '${functionCall.name}'";
        }
        

        switch (functionCall.name) {
  case 'loadUrl':
    functionResult = await webViewAIController.loadUrl(arguments['url']);
    break;
  case 'getInteractiveElements': // Add the new case
    functionResult = await webViewAIController.getInteractiveElements();
    break;
  case 'typeInElementByAiId': // Add the new case
    functionResult = await webViewAIController.typeInElementByAiId(arguments['aiId'], arguments['text']);
    break;
  case 'clickElementByAiId': // Add the new case
    functionResult = await webViewAIController.clickElementByAiId(arguments['aiId']);
    break;
  case 'readTextContent':
    functionResult = await webViewAIController.readTextContent(selector: arguments['selector']);
    break;
  default:
    functionResult = "Error: Unknown tool '${functionCall.name}'";
}
        onNewMessage("Tool result: $functionResult");

        // Add the tool's result to the message history for the AI's next turn.
        _messages.add(
          ChatCompletionMessage.tool(
            toolCallId: toolCall.id,
            content: functionResult,
          ),
        );
      }
      // Continue the loop to let the AI process the tool results.
    }
  }
}