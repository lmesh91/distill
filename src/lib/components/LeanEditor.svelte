<script lang="ts">
	import { onMount } from 'svelte';
	import { EditorSelection, EditorState, StateEffect, StateField, Text } from '@codemirror/state';
	import { Decoration, EditorView, drawSelection, keymap, lineNumbers } from '@codemirror/view';
	import { changeKeepsLines, nearestFreeLine } from '$lib/levels/lockedLines';
	import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
	import { indentUnit } from '@codemirror/language';
	import { connectLean, type Diagnostic, type LineTranslation } from '$lib/lean/client';

	let {
		value = $bindable(''),
		onstatus,
		ondiagnostics,
		ontranslation,
		lockedLines = []
	}: {
		value?: string;
		/** 1-based lines of `value` the user can't edit, tracked as lines are added around them */
		lockedLines?: number[];
		onstatus?: (status: string) => void;
		ondiagnostics?: (diagnostics: Diagnostic[]) => void;
		ontranslation?: (lines: LineTranslation[] | null) => void;
	} = $props();

	const id = $props.id();
	let container: HTMLDivElement;
	let editor: EditorView | undefined;

	function lineStarts(doc: Text, lines: number[]) {
		return lines.filter((line) => line <= doc.lines).map((line) => doc.line(line).from);
	}

	const setLocked = StateEffect.define<number[]>();
	// Start offsets of locked lines; a line inserted directly before one pushes it down.
	const locked = StateField.define<number[]>({
		create: (state) => lineStarts(state.doc, lockedLines),
		update(starts, tr) {
			for (const effect of tr.effects) if (effect.is(setLocked)) return effect.value;
			return tr.docChanged ? starts.map((start) => tr.changes.mapPos(start, 1)) : starts;
		},
		provide: (field) =>
			EditorView.decorations.compute([field], (state) =>
				Decoration.set(
					state.field(field).map((start) => lockedLine.range(start)),
					true
				)
			)
	});
	const lockedLine = Decoration.line({ class: 'cm-locked-line' });
	const keepLocked = EditorState.changeFilter.of((tr) => {
		const ranges = tr.startState.field(locked).map((start) => tr.startState.doc.lineAt(start));
		let allowed = true;
		tr.changes.iterChanges((from, to, _fromB, _toB, inserted) => {
			allowed &&= changeKeepsLines({ from, to, inserted: inserted.toString() }, ranges);
		});
		return allowed;
	});
	// Text in locked lines can still be selected for copying, but an empty caret can't rest there.
	const skipLocked = EditorState.transactionFilter.of((tr) => {
		if (!tr.selection) return tr;
		const doc = tr.newDoc;
		const lines = new Set(
			tr.startState.field(locked).map((start) => doc.lineAt(tr.changes.mapPos(start, 1)).number)
		);
		if (lines.size === 0) return tr;
		const previous = tr.startState.selection.map(tr.changes);
		let moved = false;
		const ranges = tr.selection.ranges.map((range, index) => {
			if (!range.empty) return range;
			const from = previous.ranges[index]?.head ?? range.head;
			const target = nearestFreeLine(
				doc.lineAt(range.head).number,
				range.head >= from ? 1 : -1,
				doc.lines,
				lines
			);
			if (!target || target.line === doc.lineAt(range.head).number) return range;
			moved = true;
			const line = doc.line(target.line);
			return EditorSelection.cursor(target.atEnd ? line.to : line.from);
		});
		if (!moved) return tr;
		return [
			tr,
			{ selection: EditorSelection.create(ranges, tr.selection.mainIndex), sequential: true }
		];
	});

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

		const doc = Text.of(value.split('\n'));
		const start = nearestFreeLine(1, 1, doc.lines, new Set(lockedLines));
		editor = new EditorView({
			parent: container,
			doc,
			selection: { anchor: start ? doc.line(start.line).from : 0 },
			extensions: [
				lineNumbers(),
				locked,
				keepLocked,
				skipLocked,
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
					'.cm-cursor': { borderLeftColor: '#333' },
					'.cm-locked-line': { backgroundColor: '#f3f3f3', color: '#767676', cursor: 'not-allowed' }
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
		const nextLocked = lockedLines;
		if (editor && nextValue !== editor.state.doc.toString()) {
			editor.dispatch({
				changes: { from: 0, to: editor.state.doc.length, insert: nextValue },
				effects: setLocked.of(lineStarts(Text.of(nextValue.split('\n')), nextLocked)),
				filter: false
			});
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
