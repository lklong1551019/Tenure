import type { ReactNode } from 'react'
import { type InlineNode, parseInline } from './inlineMarkdown'

/** Inline Markdown as React text and elements; whitespace kept by the `story-text` class. */
export function StoryText({ text }: { text: string }) {
  return <div className="story-text">{render(parseInline(text))}</div>
}

function render(nodes: readonly InlineNode[]): ReactNode[] {
  return nodes.map((node, index) => {
    switch (node.kind) {
      case 'text':
        return node.text
      case 'code':
        return <code key={index}>{node.text}</code>
      case 'strong':
        return <strong key={index}>{render(node.children)}</strong>
      case 'emphasis':
        return <em key={index}>{render(node.children)}</em>
      case 'link':
        return node.href ? (
          <a key={index} href={node.href} target="_blank" rel="noopener noreferrer">
            {render(node.children)}
          </a>
        ) : (
          <span key={index}>{render(node.children)}</span>
        )
    }
  })
}
