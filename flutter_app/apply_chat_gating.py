import os

filepath = "/Users/adityasingh/Desktop/Zyndio/Zyndio Mobile Apps/Zyndio-Health-Mobile-Application/flutter_app/lib/providers/chat_provider.dart"

with open(filepath, 'r') as f:
    content = f.read()

# The simulation parsing block
old_sim_block = """                           if (data['type'] == 'simulation') {
                               final simulation = SimulationResult.fromJson(data);
                               finalAiMsg = ChatMessage(
                                 text: textBeforeJson.isNotEmpty ? textBeforeJson : simulation.summary,
                                 isUser: false,
                                 simulation: simulation,
                               );
                           }"""

new_sim_block = """                           if (data['type'] == 'simulation') {
                              if (!ref.read(purchaseProvider).isPlus) {
                                finalAiMsg = ChatMessage(
                                  text: textBeforeJson.isNotEmpty ? textBeforeJson : "I've generated a simulation for you.",
                                  isUser: false,
                                  ctaActions: [CtaAction(label: 'Unlock Simulation with Plus', action: 'navigate_to_paywall')],
                                );
                              } else {
                                final simulation = SimulationResult.fromJson(data);
                                finalAiMsg = ChatMessage(
                                  text: textBeforeJson.isNotEmpty ? textBeforeJson : simulation.summary,
                                  isUser: false,
                                  simulation: simulation,
                                );
                              }
                           }"""

# The protocol parsing block (handling the weird escaping mentioned)
old_proto_block = """                           } else if (data['type'] == 'protocol') {
                               final protocol = HealthProtocol.fromJson(data);
                               finalAiMsg = ChatMessage(
                                 text: textBeforeJson.isNotEmpty ? textBeforeJson : "I've designed a personalized \\${protocol.title} for you.", 
                                 isUser: false,
                                 attachment: protocol,
                               );
                           } else if (data['type'] == 'meal_plan') {
                               final plan = MealPlan.fromJson(data);
                               finalAiMsg = ChatMessage(
                                 text: textBeforeJson.isNotEmpty ? textBeforeJson : "I've created a personalized \\${plan.name} for you.",
                                 isUser: false,
                                 mealPlan: plan,
                               );
                           }"""

new_proto_block = """                           } else if (data['type'] == 'protocol') {
                              final canGenerate = ref.read(canGenerateProtocolProvider);
                              final isPlus = ref.read(purchaseProvider).isPlus;
                              if (!canGenerate && !isPlus) {
                                finalAiMsg = ChatMessage(
                                  text: "Monthly protocol limit reached.",
                                  isUser: false,
                                  ctaActions: [CtaAction(label: 'Upgrade for Unlimited', action: 'navigate_to_paywall')],
                                );
                              } else {
                                final protocol = HealthProtocol.fromJson(data);
                                finalAiMsg = ChatMessage(
                                  text: textBeforeJson.isNotEmpty ? textBeforeJson : "I've designed a personalized ${protocol.title} for you.", 
                                  isUser: false,
                                  attachment: protocol,
                                );
                                ref.read(usageLimitProvider.notifier).incrementProtocolGenerations();
                              }
                           } else if (data['type'] == 'meal_plan') {
                              final canGenerate = ref.read(canGenerateProtocolProvider);
                              final isPlus = ref.read(purchaseProvider).isPlus;
                              if (!canGenerate && !isPlus) {
                                finalAiMsg = ChatMessage(
                                  text: "Monthly meal plan limit reached.",
                                  isUser: false,
                                  ctaActions: [CtaAction(label: 'Upgrade for Unlimited', action: 'navigate_to_paywall')],
                                );
                              } else {
                                final plan = MealPlan.fromJson(data);
                                finalAiMsg = ChatMessage(
                                  text: textBeforeJson.isNotEmpty ? textBeforeJson : "I've created a personalized ${plan.name} for you.",
                                  isUser: false,
                                  mealPlan: plan,
                                );
                                ref.read(usageLimitProvider.notifier).incrementProtocolGenerations();
                              }
                           }"""

# Try to be more flexible with whitespace if exact match fails
import re

def flexible_replace(content, old_text, new_text):
    # Escape special regex chars in old_text but then replace literal spaces with \s+
    pattern = re.escape(old_text)
    pattern = pattern.replace(r'\ ', r'\s+')
    # Also handle the escaped dollar signs specifically
    pattern = pattern.replace(r'\\\$\{', r'\\?\$\{')
    
    match = re.search(pattern, content)
    if match:
        print(f"Found match! Replacing...")
        return content[:match.start()] + new_text + content[match.end():]
    else:
        print("No match found with flexible pattern.")
        return content

content = flexible_replace(content, old_sim_block, new_sim_block)
content = flexible_replace(content, old_proto_block, new_proto_block)

with open(filepath, 'w') as f:
    f.write(content)

print("Done.")
