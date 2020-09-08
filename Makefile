fetch: subscribed-urls
	@./fetch-and-diff-gemini-links.sh <subscribed-urls >new-links.gmi
	@echo 'wrote: new-links.gmi'
	@cat new-links.gmi

subscribed-urls:
	@touch subscribed-urls
	@echo 'touched: subscribed-urls'
	@echo 'Add gemini:// URLs to this file, then run make periodically to fetch new links.'

clean:
	@rm cached-links.gmi new-links.gmi 2>/dev/null || true
	@echo 'cleaned'
