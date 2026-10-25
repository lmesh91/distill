<script lang="ts">
	import { onMount } from 'svelte';
	import { EditorState } from '@codemirror/state';
	import { EditorView, drawSelection, keymap, lineNumbers } from '@codemirror/view';
	import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
	import { indentUnit } from '@codemirror/language';
	import { connectLean, type Diagnostic, type LineTranslation } from '$lib/lean/client';

	let {
		value = $bindable(''),
		onstatus,
		ondiagnostics,
		ontranslation
	}: {
		value?: string;
		onstatus?: (status: string) => void;
		ondiagnostics?: (diagnostics: Diagnostic[]) => void;
		ontranslation?: (lines: LineTranslation[] | null) => void;
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
				ondiagnostics: (diagnostics) => ondiagnostics?.(diagnostics),
				ontranslation: ontranslation && ((lines) => ontranslation?.(lines))
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
					'&': { height: '100%', color: '#333', backgroundColor: '#fff' },
					'&.cm-focused': { outline: 'none' },
					'.cm-scroller': {
						overflow: 'auto',
						fontFamily: 'ui-monospace, SFMono-Regular, Consolas, monospace',
						fontSize: '14px',
						lineHeight: '1.8'
					},
					'.cm-content': { padding: '12px 0' },
					'.cm-line': { padding: '0 14px' },
					'.cm-gutters': {
						backgroundColor: '#f3f3f3',
						color: '#767676',
						borderRight: '1px solid #d0d0d0'
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

	// Parent-driven updates (for example, loading starter code) use the same Lean session.
	$effect(() => {
		const nextValue = value;
		if (editor && nextValue !== editor.state.doc.toString()) {
			editor.dispatch({ changes: { from: 0, to: editor.state.doc.length, insert: nextValue } });
		}
	});
</script>

<section class="lean-editor" aria-labelledby={`${id}-title`}>
	<h2 id={`${id}-title`}>Lean editor</h2>
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
		border: 2px solid #4a4a4a;
		border-radius: 6px;
		background: #fff;
		color: #333;
	}

	.lean-editor:focus-within {
		outline: 2px solid #2563eb;
		outline-offset: 2px;
	}

	h2 {
		flex: none;
		margin: 0;
		padding: 8px 12px;
		border-bottom: 2px solid #777;
		background: #f3f3f3;
		font:
			600 14px / 1.4 system-ui,
			sans-serif;
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
