---
description: Update the dev book with new learnings
---

# Dev Book Update Workflow

Update `DEVBOOK.md` with new mistakes, lessons, and patterns discovered during development.

// turbo-all

## Steps

1. **Identify what changed**

   - New mistake made?
   - New pattern discovered?
   - Tech decision made?
   - File structure changed?

2. **Update the appropriate section**

   **For mistakes:**

   - Add to "Mistakes & Lessons" section
   - Include: What went wrong, how many times made, the lesson, the rule
   - Format:

     ```markdown
     ### [Category Name]

     **Mistake:** [What went wrong]

     **Made:** X times (Session Y)

     **Lesson:** [Detailed explanation]

     **Rule:** `[One-line memorable rule]`
     ```

   **For patterns:**

   - Add to "Patterns That Work" section
   - Include: Code example, why it works
   - Format:

     ````markdown
     ### [Pattern Name]

     ```language
     // Code example
     ```
     ````

     **Why:** [Explanation]

     ```

     ```

   **For tech decisions:**

   - Update "Tech Stack Decisions" table
   - Add reasoning

   **For file changes:**

   - Update "File Structure" section

3. **Update "Last Updated" timestamp**

4. **Keep it simple**
   - One mistake = one entry
   - One pattern = one entry
   - Use code snippets sparingly
   - Make rules memorable (use backticks for emphasis)

## Philosophy

- **Compound knowledge:** Each entry makes the book more valuable
- **Future-proof:** Write for someone (human or AI) reading this 6 months from now
- **Actionable:** Every lesson should have a clear takeaway
- **Honest:** Document failures as openly as successes

## Example Usage

```
Human: "We keep forgetting to update the window size when adding UI"
AI: *Adds to DEVBOOK.md under Mistakes & Lessons*
AI: *Creates rule: "New UI Element = Check Container Size"*
```

Next time:

```
AI: *Checks DEVBOOK.md before adding UI*
AI: "I see we've made this mistake twice. Let me resize the window proactively."
```

---

_The book gets smarter. We don't repeat mistakes._
