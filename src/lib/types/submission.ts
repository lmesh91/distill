export interface LeanDiagnostic {
	severity: 'error' | 'warning' | 'information';
	message: string;
	fileName?: string;
	/** Lean positions: one-based lines and zero-based columns. */
	position?: { line: number; column: number };
	endPosition?: { line: number; column: number };
}

/** Stored by trusted level authors; never accepted from a submission request. */
export interface VerificationTarget {
	theoremName: string;
	/** Complete Lean module with the target theorem, usually proved with `sorry`. */
	challengeSource: string;
}

export interface VerificationResult {
	accepted: boolean;
	compiled: boolean;
	diagnostics: LeanDiagnostic[];
	reason:
		'accepted' | 'diagnostics' | 'missing_theorem' | 'introduced_axioms' | 'verification_failed';
	verification: {
		theoremName: string;
		dependencies: string[];
		axioms: string[];
		introducedAxioms: string[];
		message?: string;
	} | null;
}
