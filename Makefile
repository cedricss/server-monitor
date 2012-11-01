main.js: main.opa
	opa main.opa

run: main.js
	./main.js --db-remote:monitor app-key:app-secret
