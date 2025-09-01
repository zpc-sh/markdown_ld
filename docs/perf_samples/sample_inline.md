# Inline JSON‑LD Attributes

---
"@context": {"schema": "http://schema.org/", "xsd": "http://www.w3.org/2001/XMLSchema#"}
ld: {"subject": "post:1"}
---

# Post {ld:@type schema:Article}

A link to [the site](https://example.com){ld:prop schema:url} and a title
placeholder [ignored](#){ld:prop schema:name ld:value "Hello"@en}.

An image: ![logo](https://example.com/logo.png){ld:prop schema:image}

- {"@id": "post:1", "schema:tag": ["alpha","beta"]}

```
This block is ignored by extractor.
```
