import { execFile } from 'node:child_process';
import { realpath } from 'node:fs/promises';
import { resolve } from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

/** Resolve trusted, prebuilt dependencies only. Never pass submission code to Lake. */
export async function leanSandboxArgs(): Promise<string[]> {
	if (process.platform !== 'linux') {
		throw new Error('Lean submissions require Linux and Bubblewrap');
	}
	const project = resolve(process.env.LEAN_PROJECT_DIR ?? 'lean');
	const { stdout } = await execFileAsync('lake', ['env'], {
		cwd: project,
		timeout: 30_000,
		maxBuffer: 1024 * 1024,
		// Lake/elan need installation discovery, but not application credentials or Lean overrides.
		env: {
			PATH: process.env.PATH,
			HOME: process.env.HOME,
			ELAN_HOME: process.env.ELAN_HOME
		}
	});
	const environment = new Map(
		stdout
			.trim()
			.split('\n')
			.map((line) => {
				const separator = line.indexOf('=');
				return [line.slice(0, separator), line.slice(separator + 1)];
			})
	);
	const sysroot = environment.get('LEAN_SYSROOT');
	const searchPath = environment.get('LEAN_PATH');
	if (!sysroot || !searchPath) throw new Error('Lake did not provide the Lean environment');
	const toolchain = await realpath(resolve(project, sysroot));
	const imports = await Promise.all(
		searchPath
			.split(':')
			.filter(Boolean)
			.map((path) => realpath(resolve(project, path)))
	);

	// An empty mount namespace with an explicit read-only allowlist. In particular, neither
	// the app/project root nor the host's home, /tmp, /run, sockets or environment are exposed.
	const args = [
		'--unshare-all',
		'--unshare-user',
		'--disable-userns',
		'--die-with-parent',
		'--new-session',
		'--cap-drop',
		'ALL',
		'--clearenv',
		'--ro-bind',
		toolchain,
		'/toolchain'
	];
	for (const path of ['/usr/lib', '/usr/lib64', '/lib', '/lib64']) {
		args.push('--ro-bind-try', path, path);
	}
	imports.forEach((path, index) => args.push('--ro-bind', path, `/imports/${index}`));
	args.push(
		'--proc',
		'/proc',
		'--remount-ro',
		'/proc',
		'--dev',
		'/dev',
		'--tmpfs',
		'/tmp',
		'--tmpfs',
		'/work',
		'--chdir',
		'/work',
		'--setenv',
		'HOME',
		'/work',
		'--setenv',
		'TMPDIR',
		'/tmp',
		'--setenv',
		'PATH',
		'/toolchain/bin',
		'--setenv',
		'LEAN_PATH',
		imports.map((_, index) => `/imports/${index}`).join(':'),
		'--setenv',
		'LD_LIBRARY_PATH',
		'/toolchain/lib:/toolchain/lib/lean',
		'--remount-ro',
		'/',
		'--',
		'/toolchain/bin/lean',
		'--stdin'
	);
	return args;
}
