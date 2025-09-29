
## Repository/FS Embeddings

Git Repository
```
{
  "repository": {
    "folders": [
      {
        "name": ".git",
        "type": "directory",
        "hidden": true,
        "isGitFolder": true,
        "description": "Git repository data",
        "warning": "Do not modify manually"
      },
      {
        "name": "src",
        "type": "directory",
        "contains": "source code",
        "fileTypes": ["js", "ts", "jsx", "tsx"],
        "purpose": "application source"
      }
    ],
    "files": [
      {
        "name": "README.md",
        "type": "file",
        "extension": "md",
        "purpose": "documentation",
        "format": "markdown",
        "important": true
      },
      {
        "name": ".gitignore",
        "type": "file",
        "hidden": true,
        "purpose": "git ignore rules",
        "affects": "version control"
      }
    ]
  }
}
```

```
TREE_HEX_V1:
0 1ed 0755 03e8 00000000 6853f4c0 📁 .
1 1ed 0755 03e8 00000000 6853f4c0 📁 .git [ignored]
1 1ed 0755 03e8 00000000 6853f4c0 📁 src
1 1a4 0644 03e8 000003e8 6853f4c0 📄 README.md
1 1a4 0644 03e8 00000064 6853f4c0 📄 .gitignore
END_TREE
```


## Compression
