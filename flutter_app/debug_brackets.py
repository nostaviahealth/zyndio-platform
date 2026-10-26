with open('lib/screens/intelligence/intelligence_screen.dart', 'r') as f:
    content = f.read()

paren_balance = 0
bracket_balance = 0
brace_balance = 0

for i, char in enumerate(content):
    if char == '(': paren_balance += 1
    elif char == ')': paren_balance -= 1
    elif char == '[': bracket_balance += 1
    elif char == ']': bracket_balance -= 1
    elif char == '{': brace_balance += 1
    elif char == '}': brace_balance -= 1
    
    if paren_balance < 0 or bracket_balance < 0 or brace_balance < 0:
        print("Error: Balance negative at index {}".format(i))
        break

print("Final balance: P:{} B:{} C:{}".format(paren_balance, bracket_balance, brace_balance))
