import XCTest
@testable import Clip
import ClipCore

final class MarkdownToHTMLTests: XCTestCase {

    // MARK: - Fenced code blocks

    func testFencedCodeBlockRendersAsPre() {
        let md = "```swift\nlet x = 1\n# not a header\n```"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("let x = 1"))
        XCTAssertFalse(html.contains("<h1"), "Header syntax inside fences must not be parsed")
    }

    func testFencedCodeBlockEscapesHTML() {
        let md = "```\n<script>alert(1)</script>\n```"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func testFencedCodeBlockPreservesBlankLines() {
        let md = "```\nline1\n\nline2\n```\nafter"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("line1\n\nline2"))
        XCTAssertTrue(html.contains("<p>after</p>"))
    }

    func testUnterminatedFenceConsumesRemainder() {
        let md = "```\ncode here"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("<pre><code>code here</code></pre>"))
    }

    func testTildeFences() {
        let md = "~~~\ncode\n~~~"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("<pre><code>code</code></pre>"))
    }

    // MARK: - Ordered lists

    func testOrderedListRendersAsOl() {
        let md = "1. first\n2. second\n3. third"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>first</li>"))
        XCTAssertTrue(html.contains("<li>third</li>"))
        XCTAssertTrue(html.contains("</ol>"))
    }

    func testOrderedAndUnorderedListsDontMerge() {
        let md = "1. one\n- bullet"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("</ol>\n<ul>"))
    }

    func testVersionNumberParagraphIsNotAList() {
        // "1.5 release" looks like an ordered item prefix but lacks ". " after digits
        let html = RichTextTransformer.markdownToHTML("1.5 is out")
        XCTAssertFalse(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<p>1.5 is out</p>"))
    }

    // MARK: - Task lists

    func testTaskListCheckboxes() {
        let md = "- [ ] todo\n- [x] done"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("<li class=\"task\"><input type=\"checkbox\" disabled data-line=\"0\"> todo</li>"))
        XCTAssertTrue(html.contains("<li class=\"task\"><input type=\"checkbox\" disabled data-line=\"1\" checked> done</li>"))
    }

    func testTaskCheckboxDataLineSkipsFenceContent() {
        // Task syntax inside a code fence renders as code, and the real task
        // below must carry its ORIGINAL line number so toggles hit that line.
        let md = "```\n- [ ] fake task in code\n```\n- [ ] real task"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertEqual(html.components(separatedBy: "type=\"checkbox\"").count - 1, 1,
                       "Only the real task gets a checkbox")
        XCTAssertTrue(html.contains("data-line=\"3\""), "Checkbox maps to source line 3")
    }

    func testTaskCheckboxDataLineAccountsForFrontmatter() {
        let md = "---\ntitle: x\n---\n- [ ] task"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("data-line=\"3\""),
                      "Frontmatter offset must be added back to the source line index")
    }

    func testPlainListItemsUnaffectedByTaskSyntax() {
        let html = RichTextTransformer.markdownToHTML("- normal item")
        XCTAssertTrue(html.contains("<li>normal item</li>"))
        XCTAssertFalse(html.contains("checkbox"))
    }

    // MARK: - Frontmatter

    func testFrontmatterExtracted() {
        let md = "---\ntitle: Test\ndate: 2026-06-12\n---\n# Body"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("<pre class=\"frontmatter\">"))
        XCTAssertTrue(html.contains("title: Test"))
        XCTAssertTrue(html.contains("<h1"))
        XCTAssertFalse(html.contains("<hr"), "Frontmatter fences must not render as rules")
    }

    func testLeadingHorizontalRuleIsNotFrontmatter() {
        // No key: value lines between the dashes → it's two rules, not metadata
        let md = "---\njust text\n---"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertFalse(html.contains("frontmatter"))
        XCTAssertTrue(html.contains("<hr />"))
    }

    func testExtractFrontmatterReturnsNilWithoutClosingFence() {
        let lines = ["---", "title: x", "body continues"]
        XCTAssertNil(RichTextTransformer.extractFrontmatter(lines))
    }

    func testFrontmatterRejectsMixedProseBetweenRules() {
        // A changelog that opens with an hr: one 'key:'-looking line is not
        // enough — non-YAML lines like '## v1.5' must veto the frontmatter.
        let md = "---\n\n## v1.5\n\nNotes: fixed bugs\n\n---\n\n## v1.4"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertFalse(html.contains("frontmatter"))
        XCTAssertTrue(html.contains("<h2 id=\"v15\">"))
        XCTAssertTrue(html.contains("<hr />"))
    }

    // MARK: - Ordered list paragraph interruption

    func testNumberedLineDoesNotInterruptParagraph() {
        // CommonMark: only a list starting at 1 may interrupt a paragraph.
        let md = "call the desk at extension\n5) then press star"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertFalse(html.contains("<ol>"))
        XCTAssertTrue(html.contains("call the desk at extension 5) then press star"))
    }

    func testListStartingAtOneInterruptsParagraph() {
        let md = "Steps:\n1. first\n2. second"
        let html = RichTextTransformer.markdownToHTML(md)

        XCTAssertTrue(html.contains("</p>\n<ol>"))
        XCTAssertTrue(html.contains("<li>second</li>"))
    }

    // MARK: - HTML → markdown round-trip of new constructs

    func testHTMLToMarkdownRoundTripsTaskList() {
        let html = RichTextTransformer.markdownToHTML("- [ ] todo\n- [x] done")
        let md = RichTextTransformer.htmlToMarkdown(html)

        XCTAssertTrue(md.contains("- [ ] todo"))
        XCTAssertTrue(md.contains("- [x] done"))
    }

    func testHTMLToMarkdownRoundTripsOrderedList() {
        let html = RichTextTransformer.markdownToHTML("1. first\n2. second")
        let md = RichTextTransformer.htmlToMarkdown(html)

        XCTAssertTrue(md.contains("1. first"))
        XCTAssertTrue(md.contains("1. second"), "Every item emits '1.'; markdown renumbers on render")
        XCTAssertFalse(md.contains("- first"))
    }

    func testHTMLToMarkdownRoundTripsCodeFence() {
        let html = RichTextTransformer.markdownToHTML("```\nlet x = 1\nlet y = 2\n```")
        let md = RichTextTransformer.htmlToMarkdown(html)

        XCTAssertTrue(md.contains("```\nlet x = 1\nlet y = 2\n```"),
                      "Multi-line code must survive the round-trip with newlines intact")
    }

    func testHTMLToMarkdownRoundTripsFrontmatter() {
        let html = RichTextTransformer.markdownToHTML("---\ntitle: Test\n---\n# Body")
        let md = RichTextTransformer.htmlToMarkdown(html)

        XCTAssertTrue(md.contains("---\ntitle: Test\n---"))
        XCTAssertTrue(md.contains("# Body"))
    }

    // MARK: - Existing behavior still intact

    func testHeadersAndBoldStillWork() {
        let html = RichTextTransformer.markdownToHTML("# Title\n\n**bold** text")
        XCTAssertTrue(html.contains("<h1 id=\"title\">Title</h1>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
    }

    func testTablesStillWork() {
        let html = RichTextTransformer.markdownToHTML("| a | b |\n| --- | --- |\n| 1 | 2 |")
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th>a</th>"))
        XCTAssertTrue(html.contains("<td>2</td>"))
    }
}
