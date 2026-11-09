<script lang="ts">
	let {
		orientation,
		label,
		controls,
		value,
		onstart,
		onmove
	}: {
		/** direction of the bar: vertical bars sit between columns, horizontal bars between rows */
		orientation: 'horizontal' | 'vertical';
		label: string;
		/** id of the pane this handle resizes */
		controls: string;
		/** the controlled pane's size as a percentage of its group */
		value: number;
		onstart: () => void;
		/** called with the distance in pixels moved since the last `onstart` */
		onmove: (delta: number) => void;
	} = $props();

	const keyboardStep = 16;
	let origin = $state<number>();

	function position(event: PointerEvent) {
		return orientation === 'vertical' ? event.clientX : event.clientY;
	}

	function onpointerdown(event: PointerEvent & { currentTarget: HTMLDivElement }) {
		if (event.button !== 0) return;
		event.preventDefault();
		event.currentTarget.setPointerCapture(event.pointerId);
		origin = position(event);
		onstart();
	}

	function onpointermove(event: PointerEvent) {
		if (origin !== undefined) onmove(position(event) - origin);
	}

	function stop() {
		origin = undefined;
	}

	function onkeydown(event: KeyboardEvent) {
		const keys =
			orientation === 'vertical' ? ['ArrowLeft', 'ArrowRight'] : ['ArrowUp', 'ArrowDown'];
		const direction = keys.indexOf(event.key);
		if (direction === -1) return;
		event.preventDefault();
		onstart();
		onmove(direction === 0 ? -keyboardStep : keyboardStep);
	}
</script>

<!-- A focusable separator is an interactive widget (WAI-ARIA window splitter pattern). -->
<!-- svelte-ignore a11y_no_noninteractive_tabindex, a11y_no_noninteractive_element_interactions -->
<div
	class="resize-handle"
	class:vertical={orientation === 'vertical'}
	class:dragging={origin !== undefined}
	role="separator"
	tabindex="0"
	aria-orientation={orientation}
	aria-label={label}
	aria-controls={controls}
	aria-valuenow={Math.round(value)}
	aria-valuemin={0}
	aria-valuemax={100}
	{onpointerdown}
	{onpointermove}
	onpointerup={stop}
	onlostpointercapture={stop}
	{onkeydown}
>
	<svg class="grip" viewBox="0 0 10 16" aria-hidden="true">
		<circle cx="2" cy="2" r="1.2" /><circle cx="2" cy="8" r="1.2" /><circle
			cx="2"
			cy="14"
			r="1.2"
		/>
		<circle cx="8" cy="2" r="1.2" /><circle cx="8" cy="8" r="1.2" /><circle
			cx="8"
			cy="14"
			r="1.2"
		/>
	</svg>
</div>

<style>
	.resize-handle {
		position: relative;
		height: 1rem;
		cursor: row-resize;
		touch-action: none;
	}

	.resize-handle.vertical {
		width: 1rem;
		height: auto;
		cursor: col-resize;
	}

	.grip {
		position: absolute;
		top: 50%;
		left: 50%;
		width: 10px;
		height: 16px;
		opacity: 0;
		fill: #4a4a4a;
		transform: translate(-50%, -50%) rotate(90deg);
	}

	.resize-handle.vertical .grip {
		transform: translate(-50%, -50%);
	}

	.resize-handle:hover .grip,
	.resize-handle.dragging .grip,
	.resize-handle:focus-visible .grip {
		opacity: 1;
	}

	.resize-handle:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: -2px;
	}
</style>
