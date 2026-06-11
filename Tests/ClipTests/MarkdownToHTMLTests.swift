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

        XCTAssertTrue(html.contains("<li class=\"task\"><input type=\"checkbox\" disabled> todo</li>"))
        XCTAssertTrue(html.contains("<li class=\"task\"><input type=\"checkbox\" disabled checked> done</li>"))
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
