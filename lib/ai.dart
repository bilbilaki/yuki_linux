
import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:yuki/controller.dart';

final client = OpenAIClient(
  apiKey:'aa-Ag0FkYecrGW21yVnadVUT1wZt3R1Q360lAOwa',
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
