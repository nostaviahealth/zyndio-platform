with open("lib/data/health_repository.dart", "r") as f:
    lines = f.readlines()

stack = []
for i, line in enumerate(lines):
    for char in line:
        if char == '{':
            stack.append(i + 1)
        elif char == '}':
            if stack:
                stack.pop()
            else:
                print(f"Unmatched closing bracket at line {i + 1}")

if stack:
    print(f"Unmatched opening brackets at lines: {stack}")
else:
    print("All brackets match.")
