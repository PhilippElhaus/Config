import js from 'file:///C:/Users/Philipp%20Elhaus/AppData/Roaming/npm/node_modules/@eslint/js/src/index.js';

export default [
	js.configs.recommended,
	{
		languageOptions: {
			ecmaVersion: 2021,
			sourceType: 'module',
			globals: {
				browser: true,
			},
		},
		ignores: ['Private/lib/**/*'],
		rules: {
			indent: ['warn', 'tab'],
			'linebreak-style': ['warn', 'windows'],
			quotes: ['warn', 'single'],
			semi: ['warn', 'always'],
			'brace-style': ['warn', 'allman'],
			'no-fallthrough': 'off',
			'no-empty': 'off',
			'no-multi-spaces': 'warn',
			'space-in-parens': ['error', 'never'],
			'no-multiple-empty-lines': ['error', { max: 2, maxBOF: 0, maxEOF: 0 }],
			'no-mixed-spaces-and-tabs': 'warn',
			'no-unused-vars': ['warn', { vars: 'local' }],
			'no-undef': 'off',
			'no-constant-condition': 'warn',
			'padded-blocks': ['warn', 'never'],
		},
	},
];
