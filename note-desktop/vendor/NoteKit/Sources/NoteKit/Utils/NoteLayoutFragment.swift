import AppKit

public final class NoteLayoutFragment: NSTextLayoutFragment {
    public override func draw(at point: CGPoint, in context: CGContext) {
        // Here is where you can intercept drawing to render custom backgrounds,
        // side borders, or highlights for specific block types (like blockquotes or headings).
        super.draw(at: point, in: context)
    }
}
