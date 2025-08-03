


import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:webview_flutter/webview_flutter.dart';



class WebViewAIController {
  final WebViewController controller;

  WebViewAIController(this.controller);

  /// Navigates to a specific URL.
  Future<String> loadUrl(String url) async {
    try {
      await controller.loadUrl(url);
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

  /// Types text into an element found by a CSS selector.
  // Future<String> typeInElement(String selector, String text) async {
  //   final escapedText = jsonEncode(text);
  //   final js = """
  //     try {
  //       const element = document.querySelector('$selector');
  //       if (element) {
  //         element.value = $escapedText;
  //         return 'Successfully typed "$text" into element with selector "$selector".';
  //       } else {
  //         return 'Error: Element with selector "$selector" not found.';
  //       }
  //     } catch (e) {
  //       return 'Error executing script for typing: ' + e.message;
  //     }
  //   """;
  //   final result = await controller.runJavascriptReturningResult(js);
  //   return result.toString();
  // }

  // /// Clicks an element found by a CSS selector.
  // Future<String> clickElement(String selector) async {
  //   final js = """
  //     try {
  //       const element = document.querySelector('$selector');
  //       if (element) {
  //         element.click();
  //         return 'Successfully clicked element with selector "$selector".';
  //       } else {
  //         return 'Error: Element with selector "$selector" not found.';
  //       }
  //     } catch (e) {
  //       return 'Error executing script for clicking: ' + e.message;
  //     }
  //   """;
  //   final result = await controller.runJavascriptReturningResult(js);
  //   return result.toString();
  // }
  
  // /// Reads the visible text content of the entire page or a specific element.
  // Future<String> readTextContent({String? selector}) async {
  //   final target = selector != null ? "document.querySelector('$selector')" : "document.body";
  //   final js = """
  //     try {
  //       const element = $target;
  //       if (element) {
  //         // Limit the text length to avoid overflowing the AI's context window
  //         return element.innerText.trim().substring(0, 4000);
  //       } else {
  //         return 'Error: Element with selector "$selector" not found.';
  //       }
  //     } catch (e) {
  //       return 'Error reading content: ' + e.message;
  //     }
  //   """;
  //   final result = await controller.runJavascriptReturningResult(js);
  //   // Sanitize the result
  //   return result.toString().replaceAll('"', '').trim();
  // }
  Future<String> typeInElement(String selector, String text) async {
    final escapedText = jsonEncode(text);
    //
    // Notice the new (function() { ... })(); wrapper
    //
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
    final result = await controller.runJavascriptReturningResult(js);
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
    final result = await controller.runJavascriptReturningResult(js);
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
    final result = await controller.runJavascriptReturningResult(js);
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
  final result = await controller.runJavascriptReturningResult(js);
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
  return (await controller.runJavascriptReturningResult(js)).toString();
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
  return (await controller.runJavascriptReturningResult(js)).toString();
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