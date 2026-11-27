<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import { levelTypes, slugify, type LevelFormField } from '$lib/admin/levelForm';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();

	const errors = $derived<Partial<Record<LevelFormField, string>>>(form?.errors ?? {});
	const values = $derived(form?.values);

	// after a rejected save the form comes back as the admin left it. the state starts from the
	// returned values (so it also works without JavaScript) and follows later failed saves
	const returned = () => form?.values;
	// the slug follows the title until the admin edits it
	let title = $state(returned()?.title ?? '');
	let slug = $state(returned()?.slug ?? '');
	let slugEdited = $state(Boolean(returned()));
	let type = $state(returned()?.type ?? 'hints');
	let parentId = $state(returned()?.parentId ?? '');
	let order = $state(returned()?.order ?? '');
	let saving = $state(false);

	$effect.pre(() => {
		if (!values) return;
		title = values.title;
		slug = values.slug;
		slugEdited = true;
		type = values.type;
		parentId = values.parentId;
		order = values.order;
	});

	const suggestedOrder = $derived(String(data.nextOrder[parentId] ?? 0));
	const errorCount = $derived(Object.keys(errors).length);

	function onTitle() {
		if (!slugEdited) slug = slugify(title);
	}

	// links a field to its error message for screen readers
	const described = (field: LevelFormField, hint = false) =>
		[errors[field] && `${field}-error`, hint && `${field}-hint`].filter(Boolean).join(' ') ||
		undefined;
</script>

<svelte:head><title>New level · Distill admin</title></svelte:head>

<main class="admin">
	<header>
		<p class="eyebrow">Admin</p>
		<h1 class="display">New level</h1>
		<p class="muted">
			Every field is checked before the level is saved. Leave it unpublished to save a draft that
			learners can't see yet.
		</p>
	</header>

	{#if data.created}
		<p class="notice success" role="status">
			Level <strong>{data.created}</strong> created.
			<a href={resolve('/app/levels/[slug]', { slug: data.created })}>Open it</a>
			(published levels only).
		</p>
	{/if}

	{#if errorCount > 0}
		<p class="notice error" role="alert">
			{errorCount === 1 ? 'One field needs' : `${errorCount} fields need`} attention before the level
			can be saved.
		</p>
	{/if}

	<form
		method="POST"
		novalidate
		use:enhance={() => {
			saving = true;
			return async ({ update }) => {
				await update({ reset: false });
				saving = false;
			};
		}}
	>
		<fieldset class="card">
			<legend>Basics</legend>

			<label for="title">Title</label>
			<input
				id="title"
				name="title"
				bind:value={title}
				oninput={onTitle}
				maxlength="120"
				required
				aria-invalid={errors.title ? 'true' : undefined}
				aria-describedby={described('title')}
			/>
			{#if errors.title}<p class="field-error" id="title-error">{errors.title}</p>{/if}

			<label for="slug">Slug</label>
			<input
				id="slug"
				name="slug"
				bind:value={slug}
				oninput={() => (slugEdited = true)}
				required
				spellcheck="false"
				autocapitalize="off"
				aria-invalid={errors.slug ? 'true' : undefined}
				aria-describedby={described('slug', true)}
			/>
			<p class="hint" id="slug-hint">
				The level's address: /app/levels/<strong>{slug || 'slug'}</strong>. Lowercase letters and
				numbers, separated by - or _.
			</p>
			{#if errors.slug}<p class="field-error" id="slug-error">{errors.slug}</p>{/if}

			<label for="description">Description</label>
			<textarea
				id="description"
				name="description"
				rows="3"
				required
				value={values?.description ?? ''}
				aria-invalid={errors.description ? 'true' : undefined}
				aria-describedby={described('description', true)}></textarea>
			<p class="hint" id="description-hint">
				Shown on the level page. Use <code>$…$</code> for math and backticks for code.
			</p>
			{#if errors.description}
				<p class="field-error" id="description-error">{errors.description}</p>
			{/if}

			<label for="type">Type</label>
			<select
				id="type"
				name="type"
				bind:value={type}
				aria-invalid={errors.type ? 'true' : undefined}
				aria-describedby={described('type')}
			>
				{#each levelTypes as option (option.value)}
					<option value={option.value}>{option.label}</option>
				{/each}
			</select>
			{#if errors.type}<p class="field-error" id="type-error">{errors.type}</p>{/if}

			<label class="check">
				<input type="checkbox" name="published" checked={values?.published ?? false} />
				Published (learners can see and play it)
			</label>
		</fieldset>

		<fieldset class="card">
			<legend>Placement</legend>

			<label for="parentId">Comes after</label>
			<select
				id="parentId"
				name="parentId"
				bind:value={parentId}
				aria-invalid={errors.parentId ? 'true' : undefined}
				aria-describedby={described('parentId', true)}
			>
				<option value="">Nothing (a starting level)</option>
				{#each data.parents as parent (parent.id)}
					<option value={parent.id}>{parent.label}</option>
				{/each}
			</select>
			<p class="hint" id="parentId-hint">The level this one branches from in the level tree.</p>
			{#if errors.parentId}<p class="field-error" id="parentId-error">{errors.parentId}</p>{/if}

			<label for="order">Order among its siblings</label>
			<input
				id="order"
				name="order"
				type="number"
				min="0"
				step="1"
				inputmode="numeric"
				bind:value={order}
				placeholder={suggestedOrder}
				aria-invalid={errors.order ? 'true' : undefined}
				aria-describedby={described('order', true)}
			/>
			<p class="hint" id="order-hint">Lower comes first. Leave it empty for 0.</p>
			{#if errors.order}<p class="field-error" id="order-error">{errors.order}</p>{/if}
		</fieldset>

		<fieldset class="card">
			<legend>Lean</legend>

			<label for="statement">Statement</label>
			<textarea
				id="statement"
				name="statement"
				rows="2"
				required
				value={values?.statement ?? ''}
				aria-invalid={errors.statement ? 'true' : undefined}
				aria-describedby={described('statement', true)}></textarea>
			<p class="hint" id="statement-hint">
				What learners prove, as shown on the level page. Display only; checking uses the challenge
				below.
			</p>
			{#if errors.statement}
				<p class="field-error" id="statement-error">{errors.statement}</p>
			{/if}

			<label for="starterCode">Starter code</label>
			<textarea
				id="starterCode"
				name="starterCode"
				class="code"
				rows="7"
				required
				spellcheck="false"
				value={values?.starterCode ?? 'import Distill\n\ntheorem name : statement := by\n  sorry'}
				aria-invalid={errors.starterCode ? 'true' : undefined}
				aria-describedby={described('starterCode')}></textarea>
			{#if errors.starterCode}
				<p class="field-error" id="starterCode-error">{errors.starterCode}</p>
			{/if}

			<label for="lockedLines">Locked lines</label>
			<input
				id="lockedLines"
				name="lockedLines"
				value={values?.lockedLines ?? '1'}
				inputmode="numeric"
				aria-invalid={errors.lockedLines ? 'true' : undefined}
				aria-describedby={described('lockedLines', true)}
			/>
			<p class="hint" id="lockedLines-hint">
				Starter code lines learners can't edit, like <code>1, 3</code>. Usually the import.
			</p>
			{#if errors.lockedLines}
				<p class="field-error" id="lockedLines-error">{errors.lockedLines}</p>
			{/if}

			<label for="theoremName">Theorem name</label>
			<input
				id="theoremName"
				name="theoremName"
				class="code"
				required
				spellcheck="false"
				autocapitalize="off"
				value={values?.theoremName ?? ''}
				aria-invalid={errors.theoremName ? 'true' : undefined}
				aria-describedby={described('theoremName', true)}
			/>
			<p class="hint" id="theoremName-hint">
				The fully qualified name submissions must prove, like <code>Exercise.subset_rfl</code>.
			</p>
			{#if errors.theoremName}
				<p class="field-error" id="theoremName-error">{errors.theoremName}</p>
			{/if}

			<label for="challengeSource">Challenge</label>
			<textarea
				id="challengeSource"
				name="challengeSource"
				class="code"
				rows="7"
				required
				spellcheck="false"
				value={values?.challengeSource ?? ''}
				aria-invalid={errors.challengeSource ? 'true' : undefined}
				aria-describedby={described('challengeSource', true)}></textarea>
			<p class="hint" id="challengeSource-hint">
				The trusted Lean module submissions are checked against, with the theorem proved by
				<code>sorry</code>. Learners never see it.
			</p>
			{#if errors.challengeSource}
				<p class="field-error" id="challengeSource-error">{errors.challengeSource}</p>
			{/if}
		</fieldset>

		<fieldset class="card">
			<legend>Guidance</legend>

			<label for="targetProof">
				English proof {#if type === 'guided'}<span class="badge">Required for guided</span>{/if}
			</label>
			<textarea
				id="targetProof"
				name="targetProof"
				rows="4"
				value={values?.targetProof ?? ''}
				aria-invalid={errors.targetProof ? 'true' : undefined}
				aria-describedby={described('targetProof', true)}></textarea>
			<p class="hint" id="targetProof-hint">
				For guided levels: the proof whose translation learners' Lean should match.
			</p>
			{#if errors.targetProof}
				<p class="field-error" id="targetProof-error">{errors.targetProof}</p>
			{/if}

			<label for="hints">Hints</label>
			<textarea
				id="hints"
				name="hints"
				rows="4"
				value={values?.hints ?? ''}
				aria-describedby="hints-hint"></textarea>
			<p class="hint" id="hints-hint">
				One hint per line, in the order they're revealed. From-scratch levels don't show hints.
			</p>

			<label for="expectedGoal">Expected goal (optional)</label>
			<input
				id="expectedGoal"
				name="expectedGoal"
				class="code"
				spellcheck="false"
				value={values?.expectedGoal ?? ''}
				aria-describedby="expectedGoal-hint"
			/>
			<p class="hint" id="expectedGoal-hint">The goal Lean shows at the start, for display.</p>
		</fieldset>

		<div class="actions">
			<button class="button primary" type="submit" disabled={saving}>
				{saving ? 'Saving…' : 'Create level'}
			</button>
		</div>
	</form>
</main>

<style>
	.admin {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		gap: var(--space-5);
		max-width: 50rem;
		margin: 0 auto;
		padding: var(--space-7) var(--page-gutter) var(--space-8);
	}

	header p {
		margin: 0;
	}

	.eyebrow {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		font-weight: var(--weight-bold);
		text-transform: uppercase;
		letter-spacing: 0.08em;
	}

	h1 {
		margin: 0 0 var(--space-2);
		font-size: var(--text-3xl);
	}

	form {
		display: grid;
		gap: var(--space-5);
	}

	fieldset {
		display: grid;
		gap: var(--space-2);
		min-width: 0;
		margin: 0;
	}

	legend {
		/* sits inside the card instead of on its border */
		float: left;
		width: 100%;
		margin-bottom: var(--space-2);
		font-size: var(--text-lg);
		font-weight: var(--weight-bold);
	}

	label {
		margin-top: var(--space-2);
		font-weight: var(--weight-bold);
	}

	input:not([type='checkbox']),
	select,
	textarea {
		width: 100%;
		box-sizing: border-box;
		padding: var(--space-2) var(--space-3);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface);
		color: var(--color-text);
		font: inherit;
	}

	textarea {
		resize: vertical;
	}

	.code {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: var(--leading-code);
	}

	input:focus-visible,
	select:focus-visible,
	textarea:focus-visible {
		outline: 2px solid var(--color-focus);
		outline-offset: 2px;
	}

	:is(input, select, textarea)[aria-invalid='true'] {
		border-color: var(--color-error);
		background: var(--color-error-soft);
	}

	.check {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-weight: var(--weight-regular);
	}

	.check input {
		width: 1.1rem;
		height: 1.1rem;
		accent-color: var(--color-brand);
	}

	.hint,
	.field-error {
		margin: 0;
		font-size: var(--text-sm);
	}

	.hint {
		color: var(--color-text-muted);
	}

	.field-error {
		color: var(--color-error);
		font-weight: var(--weight-bold);
	}

	.notice {
		margin: 0;
		padding: var(--space-3) var(--space-4);
		border: var(--border-width) solid;
		border-radius: var(--radius);
	}

	.notice.success {
		border-color: var(--color-success);
		background: var(--color-success-soft);
	}

	.notice.error {
		border-color: var(--color-error);
		background: var(--color-error-soft);
	}

	.notice a {
		color: inherit;
		font-weight: var(--weight-bold);
	}

	.actions {
		display: flex;
		justify-content: flex-end;
	}
</style>
