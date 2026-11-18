/*
 *  app.js
 *  Markdown Previewer (LOCAL)
 *
 *  Renders an Obsidian-flavored Markdown note: markdown-it for CommonMark and
 *  GFM tables, KaTeX for $inline$ and $$display$$ math, highlight.js for code,
 *  plus Obsidian's wikilinks, embeds, callouts, ==highlights==, #tags,
 *  %%comments%%, task lists and frontmatter properties.
 *
 *  The native side calls `qlRender(text, path)` once per preview. The page stays
 *  loaded between previews, so everything here is set up only once.
 */
(() => {
	'use strict';

	const IMAGE_EXT = /\.(png|jpe?g|gif|svg|webp|bmp|avif|tiff?|heic)$/i;
	let docPath = '';
	let macros = {};

	const assetURL = name => 'qlmd://asset/?name=' + encodeURIComponent(name) + '&from=' + encodeURIComponent(docPath);

	function escapeHTML(s) {
		return s.replace(/[&<>"]/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'})[c]);
	}

	function tex(source, display) {
		// globalGroup keeps \newcommand definitions for later formulas, as in Obsidian
		const options = throwOnError => ({displayMode: display, throwOnError, output: 'html',
			strict: 'ignore', trust: false, globalGroup: true, macros});
		try {
			return katex.renderToString(source, options(true));
		} catch (e) {
			// MathJax (and so Obsidian) lets \newcommand redefine a command; KaTeX does not
			if (/redefine/.test(e.message) && source.includes('\\newcommand')) {
				try {
					return katex.renderToString(source.replace(/\\newcommand/g, '\\renewcommand'), options(true));
				} catch (e2) { /* show the error below */ }
			}
			try {
				return katex.renderToString(source, options(false));
			} catch (e3) {
				return '<code class="math-error">' + escapeHTML(source) + '</code>';
			}
		}
	}

	/*
	 * Inline and block syntax
	 */

	function mathPlugin(md) {
		// $inline$ (no space just inside the dollars) and $$display$$ within a paragraph
		md.inline.ruler.after('escape', 'math_inline', (state, silent) => {
			const src = state.src, pos = state.pos;
			if (src.charCodeAt(pos) !== 0x24 /* $ */) return false;
			const display = src.charCodeAt(pos + 1) === 0x24, open = display ? 2 : 1;
			let end = pos + open;
			for (;;) {
				end = src.indexOf(display ? '$$' : '$', end);
				if (end < 0) return false;
				if (src.charCodeAt(end - 1) !== 0x5C /* \ */) break;
				end++;
			}
			const body = src.slice(pos + open, end);
			if (!body.trim() || (!display && (/^\s/.test(body) || /\s$/.test(body)))) return false;
			if (!silent) {
				const token = state.push('math', '', 0);
				token.content = body;
				token.meta = {display};
			}
			state.pos = end + open;
			return true;
		});

		// $$ on its own line(s)
		md.block.ruler.before('fence', 'math_block', (state, start, endLine, silent) => {
			const p = state.bMarks[start] + state.tShift[start], max = state.eMarks[start];
			if (state.src.slice(p, p + 2) !== '$$') return false;
			const first = state.src.slice(p + 2, max);
			let line = start, body;
			const closed = first.trimEnd();
			if (closed.length > 2 && closed.endsWith('$$')) {
				body = closed.slice(0, -2);
			} else {
				const parts = [first];
				for (line = start + 1; line < endLine; line++) {
					const text = state.src.slice(state.bMarks[line] + state.tShift[line], state.eMarks[line]);
					const i = text.indexOf('$$');
					if (i >= 0) { parts.push(text.slice(0, i)); break; }
					parts.push(text);
				}
				if (line >= endLine) return false;
				body = parts.join('\n');
			}
			if (silent) return true;
			const token = state.push('math', '', 0);
			token.content = body;
			token.meta = {display: true};
			token.block = true;
			token.map = [start, line + 1];
			state.line = line + 1;
			return true;
		}, {alt: ['paragraph', 'blockquote', 'list']});

		md.renderer.rules.math = (tokens, i) => tex(tokens[i].content, tokens[i].meta.display);
	}

	function obsidianPlugin(md) {
		// ![[embed]] and [[wikilink]]
		md.inline.ruler.before('link', 'wikilink', (state, silent) => {
			const src = state.src, pos = state.pos;
			const embed = src.charCodeAt(pos) === 0x21 /* ! */;
			const open = pos + (embed ? 1 : 0);
			if (src.slice(open, open + 2) !== '[[') return false;
			const end = src.indexOf(']]', open + 2);
			if (end < 0) return false;
			const inner = src.slice(open + 2, end);
			if (!inner || inner.includes('\n')) return false;
			if (!silent) {
				const bar = inner.indexOf('|');
				const target = (bar < 0 ? inner : inner.slice(0, bar)).trim();
				const alias = bar < 0 ? '' : inner.slice(bar + 1).trim();
				const token = state.push('html_inline', '', 0);
				token.content = embed ? renderEmbed(target, alias) : renderWikilink(target, alias);
			}
			state.pos = end + 2;
			return true;
		});

		// ==highlight==
		md.inline.ruler.before('emphasis', 'mark', (state, silent) => {
			const src = state.src, pos = state.pos;
			if (src.charCodeAt(pos) !== 0x3D || src.charCodeAt(pos + 1) !== 0x3D /* == */) return false;
			const end = src.indexOf('==', pos + 2);
			if (end < 0 || end === pos + 2 || end > state.posMax) return false;
			if (!silent) {
				const oldMax = state.posMax;
				state.push('mark_open', 'mark', 1);
				state.pos = pos + 2;
				state.posMax = end;
				state.md.inline.tokenize(state);
				state.posMax = oldMax;
				state.push('mark_close', 'mark', -1);
			}
			state.pos = end + 2;
			return true;
		});

		// %%inline comment%%
		md.inline.ruler.before('emphasis', 'comment_inline', (state, silent) => {
			const src = state.src, pos = state.pos;
			if (src.slice(pos, pos + 2) !== '%%') return false;
			const end = src.indexOf('%%', pos + 2);
			if (end < 0) return false;
			state.pos = end + 2;
			return true;
		});

		// %% block comment %%, possibly spanning lines
		md.block.ruler.before('fence', 'comment_block', (state, start, endLine, silent) => {
			const p = state.bMarks[start] + state.tShift[start], max = state.eMarks[start];
			if (state.src.slice(p, p + 2) !== '%%') return false;
			let line = start;
			if (state.src.slice(p + 2, max).indexOf('%%') < 0) {
				for (line = start + 1; line < endLine; line++) {
					if (state.src.slice(state.bMarks[line], state.eMarks[line]).includes('%%')) break;
				}
				if (line >= endLine) return false;
			}
			if (!silent) state.line = line + 1;
			return true;
		}, {alt: ['paragraph']});

		// ^block-id at the end of a line: a link target in Obsidian, hidden when reading
		md.inline.ruler.before('emphasis', 'block_id', (state, silent) => {
			const src = state.src, pos = state.pos;
			if (src.charCodeAt(pos) !== 0x5E /* ^ */) return false;
			if (pos > 0 && !/\s/.test(src[pos - 1])) return false;
			const m = /^\^[A-Za-z0-9-]+[ \t]*(?=\n|$)/.exec(src.slice(pos, state.posMax));
			if (!m) return false;
			state.pos += m[0].length;
			return true;
		});

		// #tag (not a heading, not inside a word, not all digits)
		md.inline.ruler.before('emphasis', 'tag', (state, silent) => {
			const src = state.src, pos = state.pos;
			if (src.charCodeAt(pos) !== 0x23 /* # */) return false;
			if (pos > 0 && !/\s/.test(src[pos - 1])) return false;
			const m = /^#([\p{L}\p{N}_\-\/]+)/u.exec(src.slice(pos, state.posMax));
			if (!m || /^\d+$/.test(m[1])) return false;
			if (!silent) {
				const token = state.push('html_inline', '', 0);
				token.content = '<span class="md-tag">#' + escapeHTML(m[1]) + '</span>';
			}
			state.pos += m[0].length;
			return true;
		});
	}

	function renderWikilink(target, alias) {
		let text = alias;
		if (!text) {
			const [page, ...rest] = target.split('#');
			text = rest.length ? (page ? page + ' > ' : '') + rest.join(' > ').replace(/^\^/, '') : page;
		}
		return '<a class="internal-link" title="' + escapeHTML(target) + '">' + escapeHTML(text) + '</a>';
	}

	function renderEmbed(target, alias) {
		const name = target.split('#')[0];
		if (IMAGE_EXT.test(name)) {
			// ![[image.png|300]] or ![[image.png|300x200]] sets the size; any other alias is alt text
			const size = /^(\d+)(?:x(\d+))?$/.exec(alias);
			let attrs = ' alt="' + escapeHTML(size ? name : (alias || name)) + '"';
			if (size) attrs += ' width="' + size[1] + '"' + (size[2] ? ' height="' + size[2] + '"' : '');
			return '<img class="embed" src="' + escapeHTML(assetURL(name)) + '"' + attrs + '>';
		}
		const label = alias || target;
		return '<span class="embed-link" title="' + escapeHTML(target) + '">' + escapeHTML(label) + '</span>';
	}

	function highlightCode(code, info) {
		const lang = (info || '').trim().split(/\s+/)[0].toLowerCase();
		if (lang && window.hljs) {
			try {
				if (hljs.getLanguage(lang)) {
					return '<pre class="code"><code class="hljs language-' + escapeHTML(lang) + '">' +
						hljs.highlight(code, {language: lang, ignoreIllegals: true}).value + '</code></pre>';
				}
			} catch (e) { /* fall through to plain text */ }
		}
		return '';
	}

	const md = window.markdownit({html: true, linkify: true, breaks: true, highlight: highlightCode})
		.use(mathPlugin)
		.use(obsidianPlugin);

	/*
	 * Frontmatter properties
	 */

	function splitFrontmatter(text) {
		const m = /^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/.exec(text);
		if (!m) return {body: text, props: null};
		return {body: text.slice(m[0].length), props: m[1]};
	}

	function renderProperties(yaml) {
		// Enough YAML for Obsidian properties: `key: value`, `key: [a, b]`, and `- item` lists
		const rows = [];
		for (const line of yaml.split(/\r?\n/)) {
			const item = /^\s+-\s+(.*)$/.exec(line);
			if (item && rows.length) { rows[rows.length - 1][1].push(item[1]); continue; }
			const kv = /^([^\s:#][^:]*):\s*(.*)$/.exec(line);
			if (!kv) continue;
			let value = kv[2].trim();
			const values = /^\[.*\]$/.test(value) ? value.slice(1, -1).split(',').map(s => s.trim()).filter(Boolean)
				: value ? [value] : [];
			rows.push([kv[1].trim(), values]);
		}
		if (!rows.length) return '';
		const unquote = s => s.replace(/^(["'])(.*)\1$/, '$2');
		return '<table class="properties"><tbody>' + rows.map(([k, v]) =>
			'<tr><th>' + escapeHTML(k) + '</th><td>' + v.map(x => '<span class="property-value">' + escapeHTML(unquote(x)) + '</span>').join('') + '</td></tr>'
		).join('') + '</tbody></table>';
	}

	/*
	 * DOM post-processing
	 */

	function makeCallouts(root) {
		for (const quote of root.querySelectorAll('blockquote')) {
			const p = quote.firstElementChild;
			if (!p || p.tagName !== 'P' || !p.firstChild || p.firstChild.nodeType !== Node.TEXT_NODE) continue;
			const m = /^\[!([^\]\s]+)\]([+-]?)[ \t]*/.exec(p.firstChild.data);
			if (!m) continue;
			const type = m[1].toLowerCase();
			p.firstChild.data = p.firstChild.data.slice(m[0].length);

			// The title runs to the first line break
			const title = document.createElement('div');
			title.className = 'callout-title';
			while (p.firstChild && p.firstChild.nodeName !== 'BR') title.appendChild(p.firstChild);
			if (p.firstChild) p.removeChild(p.firstChild);
			if (p.firstChild && p.firstChild.nodeType === Node.TEXT_NODE) p.firstChild.data = p.firstChild.data.replace(/^\n/, '');
			if (!title.textContent.trim()) title.textContent = type.charAt(0).toUpperCase() + type.slice(1);
			if (!p.textContent.trim() && !p.querySelector('img, .katex')) p.remove();

			const callout = document.createElement('div');
			callout.className = 'callout';
			callout.dataset.callout = type;
			const content = document.createElement('div');
			content.className = 'callout-content';
			while (quote.firstChild) content.appendChild(quote.firstChild);
			callout.append(title);
			if (content.textContent.trim() || content.querySelector('img, .katex')) callout.append(content);
			quote.replaceWith(callout);
		}
	}

	function makeTaskLists(root) {
		for (const li of root.querySelectorAll('li')) {
			let holder = li.firstChild;
			if (holder && holder.nodeName === 'P') holder = holder.firstChild;
			if (!holder || holder.nodeType !== Node.TEXT_NODE) continue;
			const m = /^\[(.)\]\s/.exec(holder.data);
			if (!m) continue;
			holder.data = holder.data.slice(m[0].length);
			const box = document.createElement('input');
			box.type = 'checkbox';
			box.disabled = true;
			box.checked = m[1] !== ' ';
			holder.parentNode.insertBefore(box, holder);
			li.classList.add('task-list-item');
			if (box.checked) li.classList.add('is-checked');
			li.parentElement.classList.add('contains-task-list');
		}
	}

	function fixImages(root) {
		for (const img of root.querySelectorAll('img:not(.embed)')) {
			const src = img.getAttribute('src') || '';
			if (!src || /^[a-z][a-z0-9+.-]*:/i.test(src)) continue;
			let name = src;
			try { name = decodeURIComponent(src); } catch (e) { /* keep as is */ }
			img.src = assetURL(name);
		}
		// A missing attachment shows its name instead of a broken image
		for (const img of root.querySelectorAll('img')) {
			img.addEventListener('error', () => {
				const span = document.createElement('span');
				span.className = 'embed-link missing';
				span.textContent = img.alt || img.getAttribute('src');
				img.replaceWith(span);
			}, {once: true});
		}
	}

	/*
	 * Entry points for the native side
	 */

	window.qlRender = async (text, path) => {
		const t0 = performance.now();
		docPath = path || '';
		macros = {};
		const {body, props} = splitFrontmatter(text);
		const html = (props !== null ? renderProperties(props) : '') + md.render(body);
		const t1 = performance.now();

		const root = document.getElementById('doc');
		root.innerHTML = html;
		makeCallouts(root);
		makeTaskLists(root);
		fixImages(root);
		// Paragraphs left empty by hidden comments or block IDs
		for (const p of root.querySelectorAll('p')) {
			if (!p.firstElementChild && !p.textContent.trim()) p.remove();
		}
		document.scrollingElement.scrollTop = 0;
		void root.offsetHeight;   // style and layout now, not at first paint
		const t2 = performance.now();

		// Let KaTeX's web fonts load before the first paint, but never wait long
		await Promise.race([document.fonts.ready, new Promise(r => setTimeout(r, 250))]);
		const t3 = performance.now();
		return {parse: Math.round(t1 - t0), dom: Math.round(t2 - t1), fonts: Math.round(t3 - t2), length: html.length};
	};

	window.qlClear = () => { document.getElementById('doc').textContent = ''; };

	/*
	 * Warm-up, while the page waits in the pool: load KaTeX's fonts and run the
	 * renderer once, so the first real preview in this page skips both costs.
	 */

	const KATEX_FONTS = ['KaTeX_Main', 'bold 1em KaTeX_Main', 'italic 1em KaTeX_Main', 'italic 1em KaTeX_Math',
		'italic bold 1em KaTeX_Math', 'KaTeX_AMS', 'KaTeX_Size1', 'KaTeX_Size2', 'KaTeX_Size3', 'KaTeX_Size4',
		'KaTeX_Caligraphic', 'KaTeX_Fraktur', 'KaTeX_SansSerif', 'KaTeX_Script', 'KaTeX_Typewriter'];
	for (const font of KATEX_FONTS) {
		document.fonts.load(font.includes(' 1em ') ? font : '1em ' + font).catch(() => {});
	}

	const WARM_UP = [
		'---', 'tags: [a, b]', '---', '# Heading', '> [!note] Title', '> Text with $x^2$ and ==mark== #tag [[Link|alias]]', '',
		'- [ ] task', '- [x] done', '', '| a | b |', '|---|---|', '| $\\alpha$ | **b** |', '',
		'$$', '\\left\\| \\sum_{k=1}^{K} x_k \\boldsymbol{Z}_k - \\mathbf{Y} \\right\\|_{\\mathrm{F}} = \\begin{bmatrix} a & b \\\\ c & d \\end{bmatrix}^{-1} \\hat{x} \\in \\mathbb{R}^{n}', '$$', '',
		'```python', 'def f(x):', '    return x + 1  # comment', '```', '',
		'Inline $\\frac{a}{b} \\le \\sqrt{\\lambda_{\\max}}$, *em*, `code`, https://example.com'
	].join('\n');
	try {
		for (let i = 0; i < 3; i++) md.render(WARM_UP);
		const root = document.getElementById('doc');
		root.innerHTML = md.render(WARM_UP);
		makeCallouts(root);
		makeTaskLists(root);
		void root.offsetHeight;
		root.textContent = '';
	} catch (e) { /* warm-up only */ }
})();
