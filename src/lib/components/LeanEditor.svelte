<script lang="ts">
	import { onMount, type Snippet } from 'svelte';
	import { EditorState } from '@codemirror/state';
	import { EditorView, drawSelection, keymap, lineNumbers } from '@codemirror/view';
	import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
	import { indentUnit } from '@codemirror/language';
	import { connectLean, type Diagnostic } from '$lib/lean/client';

	let {
		value = $bindable(''),
		onstatus,
		ondiagnostics,
		titleBar
	}: {
		value?: string;
		// shown on the right of the editor's title bar, e.g. the save status
		titleBar?: Snippet;
		onstatus?: (status: string) => void;
		ondiagnostics?: (diagnostics: Diagnostic[]) => void;
	} = $props();

	const id = $props.id();
	let container: HTMLDivElement;
	let editor: EditorView | undefined;

	onMount(() => {
		const runtime = connectLean(
			new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/lean`),
			value,
			{
				onstatus: (status) => onstatus?.(status),
				ondiagnostics: (diagnostics) => ondiagnostics?.(diagnostics)
			}
		);

		editor = new EditorView({
			parent: container,
			doc: value,
			extensions: [
				lineNumbers(),
				history(),
				drawSelection(),
				EditorState.tabSize.of(2),
				indentUnit.of('  '),
				keymap.of([...defaultKeymap, ...historyKeymap, indentWithTab]),
				EditorView.contentAttributes.of({
					'aria-labelledby': `${id}-title`,
					'aria-describedby': `${id}-help`,
					'aria-multiline': 'true',
					spellcheck: 'false',
					autocapitalize: 'off',
					autocorrect: 'off'
				}),
				EditorView.updateListener.of((update) => {
					if (!update.docChanged) return;
					value = update.state.doc.toString();
					runtime.update(value);
				}),
				EditorView.theme({
					// colors and fonts come from the design system (src/lib/styles/tokens.css)
					'&': {
						height: '100%',
						color: 'var(--color-text)',
						backgroundColor: 'var(--color-surface)'
					},
					'&.cm-focused': { outline: 'none' },
					'.cm-scroller': {
						overflow: 'auto',
						fontFamily: 'var(--font-mono)',
						fontSize: '14px',
						lineHeight: 'var(--leading-code)'
					},
					'.cm-content': { padding: '12px 0' },
					'.cm-line': { padding: '0 14px' },
					'.cm-gutters': {
						backgroundColor: 'var(--color-surface-sunken)',
						color: 'var(--color-text-subtle)',
						borderRight: '1px solid var(--color-border-subtle)'
					},
					'.cm-lineNumbers .cm-gutterElement': { minWidth: '36px', padding: '0 10px' },
					'.cm-cursor': { borderLeftColor: '#333' }
				})
			]
		});

		return () => {
			editor?.destroy();
			editor = undefined;
			runtime.dispose();
		};
	});

	/**
	 * moves the cursor to a 0-based Lean position, scrolls it into view and focuses the editor
	 * used by the results panel to jump to an error
	 */
	export function goTo(line: number, character = 0) {
		if (!editor) return;
		const doc = editor.state.doc;
		const target = doc.line(Math.min(Math.max(line + 1, 1), doc.lines));
		const pos = target.from + Math.min(Math.max(character, 0), target.length);
		editor.dispatch({ selection: { anchor: pos }, scrollIntoView: true });
		editor.focus();
	}

	// parent-driven updates use the same Lean session
	$effect(() => {
		const nextValue = value;
		if (editor && nextValue !== editor.state.doc.toString()) {
			editor.dispatch({ changes: { from: 0, to: editor.state.doc.length, insert: nextValue } });
		}
	});
</script>

<section class="lean-editor" aria-labelledby={`${id}-title`}>
	<div class="title-bar">
		<h2 id={`${id}-title`}>Lean editor</h2>
		{@render titleBar?.()}
	</div>
	<div class="editor-container" bind:this={container}></div>
	<p class="keyboard-help" id={`${id}-help`}>
		Tab indents; Shift+Tab outdents. Press Escape then Tab to move focus out of the editor.
	</p>
</section>

<style>
	.lean-editor {
		display: flex;
		flex: 1 1 auto;
		flex-direction: column;
		min-width: 0;
		min-height: 0;
		overflow: hidden;
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface);
		color: var(--color-text);
	}

	.lean-editor:focus-within {
		outline: 2px solid var(--color-focus);
		outline-offset: 2px;
	}

	.title-bar {
		display: flex;
		flex: none;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		min-width: 0;
		padding: var(--space-2) var(--space-3);
		border-bottom: var(--border-width) solid var(--color-border);
		background: var(--color-surface-sunken);
	}

	h2 {
		flex: none;
		margin: 0;
		white-space: nowrap;
		font: var(--weight-bold) var(--text-sm) / 1.4 var(--font-body);
	}

	/* cursor and selection colors from the design system; these win over the CodeMirror theme */
	.lean-editor :global(.cm-cursor) {
		border-left: 2px solid var(--color-ink);
	}

	.lean-editor :global(.cm-activeLineGutter) {
		color: var(--color-ink);
	}

	.lean-editor :global(.cm-focused .cm-selectionBackground),
	.lean-editor :global(.cm-selectionBackground) {
		background-color: var(--color-brand-soft);
	}

	.editor-container {
		flex: 1 1 var(--lean-editor-height, 400px);
		min-height: 0;
	}

	.keyboard-help {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		overflow: hidden;
		clip-path: inset(50%);
		white-space: nowrap;
	}
</style>
