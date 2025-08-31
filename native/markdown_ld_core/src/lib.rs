use pulldown_cmark::{Event, Options, Parser, Tag};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Heading {
    pub level: u32,
    pub text: String,
    pub line: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Link {
    pub text: String,
    pub url: String,
    pub line: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedDoc {
    pub headings: Vec<Heading>,
    pub links: Vec<Link>,
}

/// Parse basic structure (headings, links) without any NIF bindings.
pub fn parse_basic(markdown: &str) -> ParsedDoc {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);

    let parser = Parser::new_ext(markdown, options);

    let mut headings = Vec::new();
    let mut links = Vec::new();

    let mut current_line: usize = 1;
    let mut in_heading = false;
    let mut heading_level: u32 = 1;
    let mut heading_text = String::new();

    for event in parser {
        match event {
            Event::Start(Tag::Heading(level, _, _)) => {
                in_heading = true;
                heading_level = match level {
                    pulldown_cmark::HeadingLevel::H1 => 1,
                    pulldown_cmark::HeadingLevel::H2 => 2,
                    pulldown_cmark::HeadingLevel::H3 => 3,
                    pulldown_cmark::HeadingLevel::H4 => 4,
                    pulldown_cmark::HeadingLevel::H5 => 5,
                    pulldown_cmark::HeadingLevel::H6 => 6,
                };
                heading_text.clear();
            }
            Event::End(Tag::Heading(_, _, _)) => {
                if in_heading {
                    headings.push(Heading {
                        level: heading_level,
                        text: heading_text.clone(),
                        line: current_line,
                    });
                    in_heading = false;
                }
            }
            Event::Start(Tag::Link(_, dest_url, title)) => {
                let mut text = String::new();
                if !title.is_empty() {
                    text.push_str(&title);
                }
                links.push(Link { text, url: dest_url.to_string(), line: current_line });
            }
            Event::Text(text) => {
                if in_heading {
                    heading_text.push_str(&text);
                }
                current_line += text.chars().filter(|&c| c == '\n').count();
            }
            Event::SoftBreak | Event::HardBreak => {
                current_line += 1;
            }
            _ => {}
        }
    }

    ParsedDoc { headings, links }
}

pub mod attr_object {
    use serde_json::{Map, Value};

    #[derive(Debug)]
    pub enum Error {
        ParseError(String),
        LimitExceeded,
    }

    pub struct Limits {
        pub max_depth: usize,
        pub max_list: usize,
        pub max_size: usize,
    }

    impl Default for Limits {
        fn default() -> Self {
            Self { max_depth: 32, max_list: 1024, max_size: 16 * 1024 }
        }
    }

    pub fn parse_attr_object(input: &str, limits: Option<Limits>) -> Result<Map<String, Value>, Error> {
        let lim = limits.unwrap_or_default();
        if input.len() > lim.max_size { return Err(Error::LimitExceeded) }
        let s = input.trim();
        let s = if s.starts_with('{') { &s[1..] } else { s };
        let s = s.rsplit_once('}').map(|(a, _)| a).unwrap_or(s);
        let mut map = Map::new();
        let mut i = 0usize;
        let b = s.as_bytes();
        while i < b.len() {
            skip_ws(b, &mut i);
            if i >= b.len() { break; }
            let key_start = i;
            while i < b.len() && is_key_char(b[i]) { i += 1; }
            let key = &s[key_start..i];
            skip_ws(b, &mut i);
            if i < b.len() && b[i] == b'=' { i += 1; } else { return Err(Error::ParseError("expected '='".into())) }
            skip_ws(b, &mut i);
            let (val, ni) = parse_value(s, i, &lim, 0)?;
            i = ni;
            map.insert(key.to_string(), val);
            skip_ws(b, &mut i);
            if i < b.len() && (b[i] == b',' || b[i].is_ascii_whitespace()) { i += 1; }
        }
        Ok(map)
    }

    fn skip_ws(b: &[u8], i: &mut usize) { while *i < b.len() && b[*i].is_ascii_whitespace() { *i += 1; } }
    fn is_key_char(c: u8) -> bool { c.is_ascii_alphanumeric() || c == b'_' || c == b'-' || c == b'.' || c == b':' || c == b'[' || c == b']' }

    fn parse_value(s: &str, mut i: usize, lim: &Limits, depth: usize) -> Result<(Value, usize), Error> {
        if depth > lim.max_depth { return Err(Error::LimitExceeded) }
        let b = s.as_bytes();
        if i >= b.len() { return Err(Error::ParseError("unexpected end".into())) }
        match b[i] {
            b'"' => {
                i += 1; let start = i; let mut esc = false;
                while i < b.len() {
                    if esc { esc = false; i += 1; continue; }
                    if b[i] == b'\\' { esc = true; i += 1; continue; }
                    if b[i] == b'"' { break; }
                    i += 1;
                }
                if i >= b.len() { return Err(Error::ParseError("unterminated string".into())) }
                let raw = &s[start..i];
                i += 1;
                Ok((Value::String(raw.to_string()), i))
            }
            b'[' => {
                i += 1; let mut arr = Vec::new(); let mut count = 0;
                loop {
                    skip_ws(b, &mut i);
                    if i >= b.len() { return Err(Error::ParseError("unterminated list".into())) }
                    if b[i] == b']' { i += 1; break; }
                    let (v, ni) = parse_value(s, i, lim, depth+1)?; i = ni; arr.push(v); count += 1;
                    if count > lim.max_list { return Err(Error::LimitExceeded) }
                    skip_ws(b, &mut i);
                    if i < b.len() && b[i] == b',' { i += 1; }
                }
                Ok((Value::Array(arr), i))
            }
            b'{' => {
                // naive nested object: find matching brace and recurse
                let mut depth_b = 1; i += 1; let start = i;
                while i < b.len() && depth_b > 0 { if b[i] == b'{' { depth_b += 1; } else if b[i] == b'}' { depth_b -= 1; } i += 1; }
                if depth_b != 0 { return Err(Error::ParseError("unterminated object".into())) }
                let inner = &s[start..i-1];
                let m = parse_attr_object(inner, Some(Limits{..*lim}))?;
                Ok((Value::Object(m), i))
            }
            b'<' => {
                i += 1; let start = i; while i < b.len() && b[i] != b'>' { i += 1; }
                if i >= b.len() { return Err(Error::ParseError("unterminated IRI".into())) }
                let iri = &s[start..i]; i += 1;
                let mut m = Map::new(); m.insert("@id".to_string(), Value::String(iri.to_string()));
                Ok((Value::Object(m), i))
            }
            _ => {
                let start = i; while i < b.len() && !b[i].is_ascii_whitespace() && b[i] != b',' && b[i] != b']' && b[i] != b'}' { i += 1; }
                let tok = &s[start..i];
                if tok.eq_ignore_ascii_case("true") { return Ok((Value::Bool(true), i)); }
                if tok.eq_ignore_ascii_case("false") { return Ok((Value::Bool(false), i)); }
                if let Ok(n) = tok.parse::<i64>() { return Ok((Value::from(n), i)); }
                if let Ok(f) = tok.parse::<f64>() { return Ok((Value::from(f), i)); }
                Ok((Value::String(tok.to_string()), i))
            }
        }
    }
}
