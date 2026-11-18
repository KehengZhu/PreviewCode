/*
 *  notebook.js
 *  Markdown Previewer (LOCAL)
 *
 *  Renders a Jupyter notebook (nbformat 4) to HTML: Markdown cells through the
 *  page's Markdown setup (so math, callouts and so on work as in notes), code
 *  cells highlighted in the kernel's language, and their outputs: text streams,
 *  errors with ANSI colors, images, HTML, LaTeX, Markdown and JSON.
 *
 *  Raw HTML outputs cannot run scripts: the page's Content-Security-Policy
 *  blocks them, so widgets and interactive plots fall back to a static output
 *  when the notebook saved one.
 */
'use strict';

function renderNotebook(nb, {md, escapeHTML}) {

	if (!Array.isArray(nb.cells)) {
		const version = nb.nbformat ? 'nbformat ' + nb.nbformat : 'this format';
		return '<p class="nb-unsupported">Notebooks in ' + escapeHTML(version) + ' cannot be previewed.</p>';
	}

	const meta = nb.metadata || {};
	const language = ((meta.language_info || {}).name || (meta.kernelspec || {}).language || 'python').toLowerCase();
	const text = value => Array.isArray(value) ? value.join('') : (value == null ? '' : String(value));

	function highlight(code, lang) {
		try {
			if (window.hljs && hljs.getLanguage(lang)) {
				return hljs.highlight(code, {language: lang, ignoreIllegals: true}).value;
			}
		} catch (e) { /* plain text below */ }
		return escapeHTML(code);
	}

	function prompt(label, count) {
		return '<div class="nb-prompt">' + (label ? label + '[' + (count == null ? ' ' : count) + ']:' : '') + '</div>';
	}

	function markdownCell(cell) {
		let source = text(cell.source);
		// Pasted images live in the cell as `attachment:name`
		const attachments = cell.attachments || {};
		source = source.replace(/attachment:([^\s)"'>]+)/g, (whole, name) => {
			const bundle = attachments[decodeURIComponent(name)] || attachments[name];
			const mime = bundle && Object.keys(bundle).find(k => k.startsWith('image/'));
			return mime ? 'data:' + mime + ';base64,' + text(bundle[mime]).replace(/\s/g, '') : whole;
		});
		return '<div class="nb-cell nb-markdown">' + prompt('') + '<div class="nb-body">' + md.render(source) + '</div></div>';
	}

	function codeCell(cell) {
		const source = text(cell.source);
		const outputs = (cell.outputs || []).map(output).join('');
		return '<div class="nb-cell nb-code">' + prompt('In ', cell.execution_count) +
			'<pre class="nb-input"><code class="hljs">' + highlight(source, language) + '</code></pre></div>' +
			(outputs ? '<div class="nb-outputs">' + outputs + '</div>' : '');
	}

	function rawCell(cell) {
		return '<div class="nb-cell nb-raw">' + prompt('') + '<pre class="nb-input">' + escapeHTML(text(cell.source)) + '</pre></div>';
	}

	/*
	 * Outputs
	 */

	function output(out) {
		switch (out.output_type) {
			case 'stream':
				return outputRow('', '<pre class="nb-stream' + (out.name === 'stderr' ? ' nb-stderr' : '') + '">' +
					ansiToHTML(collapseCarriageReturns(text(out.text))) + '</pre>');
			case 'error':
				// VS Code writes links to the failing cell into the traceback; keep their text
				return outputRow('', '<pre class="nb-error">' +
					ansiToHTML((out.traceback || []).join('\n').replace(/<a\s[^>]*>|<\/a>/g, '')) + '</pre>');
			case 'execute_result':
				return outputRow(prompt('Out', out.execution_count), richOutput(out.data || {}));
			case 'display_data':
				return outputRow('', richOutput(out.data || {}));
			default:
				return '';
		}
	}

	function outputRow(promptHTML, body) {
		return body ? '<div class="nb-output">' + (promptHTML || prompt('')) + '<div class="nb-output-body">' + body + '</div></div>' : '';
	}

	function richOutput(data) {
		const html = data['text/html'] !== undefined ? text(data['text/html']) : null;
		const image = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'].find(k => data[k] !== undefined);
		// HTML that needs scripts (widgets, interactive plots) shows nothing here, so
		// prefer a saved image or text
		const scripted = html !== null && /<script\b/i.test(html);

		if (html !== null && !scripted) return '<div class="nb-html">' + html + '</div>';
		if (image) return '<img class="nb-image" loading="lazy" decoding="async" src="data:' + image + ';base64,' + text(data[image]).replace(/\s/g, '') + '">';
		if (data['image/svg+xml'] !== undefined) {
			return '<img class="nb-image" decoding="async" src="data:image/svg+xml;charset=utf-8,' + encodeURIComponent(text(data['image/svg+xml'])) + '">';
		}
		if (data['text/latex'] !== undefined) return '<div class="nb-latex">' + md.render(text(data['text/latex'])) + '</div>';
		if (data['text/markdown'] !== undefined) return '<div class="nb-md">' + md.render(text(data['text/markdown'])) + '</div>';
		if (data['application/json'] !== undefined) {
			return '<pre class="nb-text">' + highlight(JSON.stringify(data['application/json'], null, 2), 'json') + '</pre>';
		}
		if (data['text/plain'] !== undefined) return '<pre class="nb-text">' + ansiToHTML(text(data['text/plain'])) + '</pre>';
		return scripted ? '<p class="nb-unsupported">Interactive output (needs JavaScript)</p>' : '';
	}

	// Progress bars rewrite their line with \r; keep only the final state of each line
	function collapseCarriageReturns(s) {
		return s.includes('\r') ? s.split('\n').map(line => line.slice(line.lastIndexOf('\r') + 1)).join('\n') : s;
	}

	/*
	 * ANSI colors (tracebacks, colored logs)
	 */

	const ANSI_COLORS = ['ansi-black', 'ansi-red', 'ansi-green', 'ansi-yellow', 'ansi-blue', 'ansi-magenta', 'ansi-cyan', 'ansi-white'];

	function ansiToHTML(s) {
		if (!s.includes('\x1b')) return escapeHTML(s);
		// Keep color codes (CSI ... m); drop cursor and other control sequences
		s = s.replace(/\x1b\[[0-9;?]*[A-Za-ln-z]|\x1b\][^\x07]*(\x07|\x1b\\)|\x1b[()][A-Z0-9]/g, '');
		let html = '', open = false;
		let fg = null, bg = null, bold = false;
		const parts = s.split(/\x1b\[([0-9;]*)m/);
		for (let i = 0; i < parts.length; i++) {
			if (i % 2 === 0) {
				if (!parts[i]) continue;
				const classes = [fg && fg.cls, bg && bg.cls, bold && 'ansi-bold'].filter(Boolean);
				const styles = [fg && fg.rgb && 'color:' + fg.rgb, bg && bg.rgb && 'background:' + bg.rgb].filter(Boolean);
				if (classes.length || styles.length) {
					html += '<span' + (classes.length ? ' class="' + classes.join(' ') + '"' : '') +
						(styles.length ? ' style="' + styles.join(';') + '"' : '') + '>' + escapeHTML(parts[i]) + '</span>';
				} else {
					html += escapeHTML(parts[i]);
				}
				continue;
			}
			const codes = parts[i] === '' ? [0] : parts[i].split(';').map(Number);
			for (let j = 0; j < codes.length; j++) {
				const c = codes[j];
				if (c === 0) { fg = bg = null; bold = false; }
				else if (c === 1) bold = true;
				else if (c === 22) bold = false;
				else if (c >= 30 && c <= 37) fg = {cls: ANSI_COLORS[c - 30]};
				else if (c >= 90 && c <= 97) fg = {cls: ANSI_COLORS[c - 90] + ' ansi-bright'};
				else if (c >= 40 && c <= 47) bg = {cls: ANSI_COLORS[c - 40] + '-bg'};
				else if (c === 39) fg = null;
				else if (c === 49) bg = null;
				else if ((c === 38 || c === 48) && codes[j + 1] === 2) {
					const color = {rgb: 'rgb(' + codes.slice(j + 2, j + 5).join(',') + ')'};
					if (c === 38) fg = color; else bg = color;
					j += 4;
				} else if ((c === 38 || c === 48) && codes[j + 1] === 5) {
					const n = codes[j + 2];
					const color = n < 8 ? {cls: ANSI_COLORS[n] + (c === 48 ? '-bg' : '')} : {rgb: xterm256(n)};
					if (c === 38) fg = color; else bg = color;
					j += 2;
				}
			}
		}
		return html;
	}

	function xterm256(n) {
		if (n < 16) return ['#000', '#c00', '#0a0', '#a50', '#00c', '#a0a', '#0aa', '#aaa', '#555', '#f55', '#5f5', '#ff5', '#55f', '#f5f', '#5ff', '#fff'][n];
		if (n >= 232) { const v = 8 + (n - 232) * 10; return 'rgb(' + v + ',' + v + ',' + v + ')'; }
		const i = n - 16, level = x => x ? 55 + x * 40 : 0;
		return 'rgb(' + level(Math.floor(i / 36)) + ',' + level(Math.floor(i / 6) % 6) + ',' + level(i % 6) + ')';
	}

	return nb.cells.map(cell =>
		cell.cell_type === 'markdown' ? markdownCell(cell) : cell.cell_type === 'code' ? codeCell(cell) : rawCell(cell)
	).join('');
}
