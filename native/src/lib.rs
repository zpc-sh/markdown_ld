use lazy_static::lazy_static;
use pulldown_cmark::{CodeBlockKind, Event, HeadingLevel, Options, Parser, Tag};
use regex::Regex;
use rustler::{Encoder, Env, Resource, Term};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        nil,
        // v0.3.0 atoms
        parse_error,
        unknown_prefix,
        invalid_context,
        limit_exceeded,
        invalid_value,
        invalid_list,
        invalid_iri,
        // Mem8 atoms
        mem8_context,
        wave_pattern,
        consciousness_state,
        // Polyglot atoms
        polyglot_detected,
        dockerfile,
        kubernetes,
        terraform,
        executable,
    }
}

// Resource types for complex data structures
#[derive(Debug)]
pub struct Mem8Context {
    pub wave_grid: Arc<Mutex<WaveGrid>>,
    pub consciousness: ConsciousnessState,
    pub memory_index: MemIndex,
}

impl Resource for Mem8Context {}

#[derive(Debug)]
pub struct PolyglotDocument {
    pub language: String,
    pub artifacts: Vec<Artifact>,
    pub metadata: HashMap<String, String>,
    pub concealment: ConcealmentData,
}

impl Resource for PolyglotDocument {}

// Core data structures from mem8
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WaveGrid {
    pub width: usize,
    pub height: usize,
    pub depth: usize,
    pub grid: Vec<Option<MemoryWave>>,
    pub noise_floor: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryWave {
    pub amplitude: f32,
    pub frequency: f32,
    pub phase: f32,
    pub valence: f32,
    pub arousal: f32,
    pub decay_tau: Option<f32>, // Seconds
}

#[derive(Debug, Clone)]
pub struct ConsciousnessState {
    pub attention_weights: HashMap<String, f32>,
    pub active_memories: Vec<MemoryWave>,
    pub awareness_level: f32,
}

#[derive(Debug, Clone)]
pub struct MemIndex {
    pub version: String,
    pub blocks: HashMap<String, BlockMeta>,
    pub projects: HashMap<String, ProjectInfo>,
}

#[derive(Debug, Clone)]
pub struct BlockMeta {
    pub filename: String,
    pub size: usize,
    pub topics: Vec<String>,
    pub summary: String,
}

#[derive(Debug, Clone)]
pub struct ProjectInfo {
    pub name: String,
    pub status: String,
    pub tech_stack: Vec<String>,
}

// Polyglot detection structures
#[derive(Debug, Clone)]
pub struct Artifact {
    pub artifact_type: String,
    pub content: String,
    pub language: Option<String>,
    pub line_start: usize,
    pub line_end: usize,
}

#[derive(Debug, Clone)]
pub struct ConcealmentData {
    pub zero_width_chars: Vec<u8>,
    pub content_addressed_links: Vec<String>,
    pub whitespace_patterns: Vec<u8>,
    pub html_comments: Vec<String>,
}

// RFC 8785 JCS implementation
lazy_static! {
    static ref JCS_REGEX: Regex = Regex::new(r#""([^"\\]|\\.)*""#).unwrap();
    static ref POLYGLOT_DETECTORS: Vec<PolyglotDetector> = vec![
        PolyglotDetector::new(
            "dockerfile",
            r"(?i)FROM\s+\w+",
            r"(?i)(RUN|COPY|ADD|ENV|EXPOSE|CMD|ENTRYPOINT)"
        ),
        PolyglotDetector::new(
            "kubernetes",
            r"apiVersion:\s*v\d",
            r"(?i)(kind:|metadata:|spec:)"
        ),
        PolyglotDetector::new(
            "terraform",
            r"resource\s+",
            r"(?i)(provider|resource|data|variable)"
        ),
        PolyglotDetector::new("bash", r"#!/bin/(bash|sh)", r"(?i)(echo|cd|mkdir|cp|mv)"),
    ];
}

#[derive(Debug, Clone)]
pub struct PolyglotDetector {
    pub language: String,
    pub primary_pattern: Regex,
    pub secondary_pattern: Regex,
}

impl PolyglotDetector {
    pub fn new(lang: &str, primary: &str, secondary: &str) -> Self {
        Self {
            language: lang.to_string(),
            primary_pattern: Regex::new(primary).unwrap(),
            secondary_pattern: Regex::new(secondary).unwrap(),
        }
    }
}

// Zero-width character concealment
const ZERO_WIDTH_CHARS: &[char] = &[
    '\u{200B}', // Zero-width space
    '\u{200C}', // Zero-width non-joiner
    '\u{200D}', // Zero-width joiner
    '\u{2060}', // Word joiner
    '\u{FEFF}', // Zero-width no-break space
];

// Main NIF functions
#[rustler::nif]
fn parse_markdown<'a>(env: Env<'a>, content: String, options: Vec<(String, String)>) -> Term<'a> {
    let result = parse_markdown_content(env, &content, &options);
    match result {
        Ok(parsed) => (atoms::ok(), parsed).encode(env),
        Err(e) => (atoms::error(), format!("Parse error: {:?}", e)).encode(env),
    }
}

#[rustler::nif]
fn parse_with_mem8<'a>(env: Env<'a>, content: String, _mem8_context: Term<'a>) -> Term<'a> {
    // Extract mem8 context from resource or create default
    let context = create_default_mem8_context();

    match parse_with_memory_context(env, &content, &context) {
        Ok(result) => (atoms::ok(), result).encode(env),
        Err(e) => (atoms::error(), format!("Mem8 parse error: {:?}", e)).encode(env),
    }
}

#[rustler::nif]
fn detect_polyglot<'a>(env: Env<'a>, content: String) -> Term<'a> {
    match detect_polyglot_document(&content) {
        Some(polyglot) => {
            let mut result = HashMap::new();
            result.insert("detected".to_string(), true.encode(env));
            result.insert("language".to_string(), polyglot.language.encode(env));
            result.insert(
                "artifacts_count".to_string(),
                polyglot.artifacts.len().encode(env),
            );

            let artifacts: Vec<Term> = polyglot
                .artifacts
                .iter()
                .map(|a| {
                    let mut artifact = HashMap::new();
                    artifact.insert("type".to_string(), a.artifact_type.encode(env));
                    artifact.insert("content".to_string(), a.content.encode(env));
                    artifact.insert("line_start".to_string(), a.line_start.encode(env));
                    artifact.insert("line_end".to_string(), a.line_end.encode(env));
                    artifact.encode(env)
                })
                .collect();

            result.insert("artifacts".to_string(), artifacts.encode(env));
            (atoms::ok(), result).encode(env)
        }
        None => {
            let mut result = HashMap::new();
            result.insert("detected".to_string(), false.encode(env));
            (atoms::ok(), result).encode(env)
        }
    }
}

#[rustler::nif]
fn extract_concealed_data<'a>(env: Env<'a>, content: String) -> Term<'a> {
    let concealment = extract_all_concealment(&content);

    let mut result = HashMap::new();
    result.insert(
        "zero_width_found".to_string(),
        (!concealment.zero_width_chars.is_empty()).encode(env),
    );
    result.insert(
        "content_links_count".to_string(),
        concealment.content_addressed_links.len().encode(env),
    );
    result.insert(
        "html_comments_count".to_string(),
        concealment.html_comments.len().encode(env),
    );

    if !concealment.zero_width_chars.is_empty() {
        if let Ok(decoded) = decode_zero_width_data(&concealment.zero_width_chars) {
            result.insert("decoded_data".to_string(), decoded.encode(env));
        }
    }

    (atoms::ok(), result).encode(env)
}

#[rustler::nif]
fn hide_data_zero_width<'a>(env: Env<'a>, text: String, data: String) -> Term<'a> {
    let encoded = encode_zero_width_data(&data);
    let hidden_text = format!("{}{}", text, encoded);
    (atoms::ok(), hidden_text).encode(env)
}

#[rustler::nif]
fn generate_stable_id<'a>(
    env: Env<'a>,
    heading_path: Vec<String>,
    block_index: u32,
    text: String,
) -> Term<'a> {
    let stable_id = generate_stable_chunk_id(&heading_path, block_index, &text);
    (atoms::ok(), stable_id).encode(env)
}

#[rustler::nif]
fn canonicalize_json<'a>(env: Env<'a>, json_str: String) -> Term<'a> {
    match json_canonicalize(&json_str) {
        Ok(canonical) => (atoms::ok(), canonical).encode(env),
        Err(e) => (atoms::error(), format!("JCS error: {}", e)).encode(env),
    }
}

#[rustler::nif]
fn parse_attribute_object<'a>(env: Env<'a>, attr_str: String, mode: String) -> Term<'a> {
    let strict = mode == "strict";
    match parse_attribute_object_mini_grammar(&attr_str, strict) {
        Ok(attrs) => {
            let encoded_attrs: HashMap<String, Term> = attrs
                .into_iter()
                .map(|(k, v)| (k, encode_attribute_value(env, v)))
                .collect();
            (atoms::ok(), encoded_attrs).encode(env)
        }
        Err(e) => (atoms::error(), format!("Attribute parse error: {:?}", e)).encode(env),
    }
}

#[rustler::nif]
fn create_memory_wave<'a>(env: Env<'a>, frequency: f32, amplitude: f32, phase: f32) -> Term<'a> {
    let wave = MemoryWave {
        amplitude,
        frequency: frequency.clamp(0.0, 1000.0),
        phase,
        valence: 0.0,
        arousal: 0.0,
        decay_tau: Some(5.0), // 5 second default decay
    };

    let mut wave_data = HashMap::new();
    wave_data.insert("amplitude".to_string(), wave.amplitude.encode(env));
    wave_data.insert("frequency".to_string(), wave.frequency.encode(env));
    wave_data.insert("phase".to_string(), wave.phase.encode(env));

    (atoms::ok(), wave_data).encode(env)
}

#[rustler::nif]
fn wave_interference<'a>(env: Env<'a>, _waves: Vec<Term<'a>>, t: f32) -> Term<'a> {
    // Simplified wave interference calculation
    let total_amplitude: f32;

    // This would extract wave data from terms and calculate interference
    // For now, return a placeholder
    total_amplitude = (t * 2.0 * std::f32::consts::PI * 100.0).sin() * 0.5;

    (atoms::ok(), total_amplitude).encode(env)
}

// Implementation functions
fn parse_markdown_content<'a>(
    env: Env<'a>,
    content: &str,
    _options: &[(String, String)],
) -> Result<Term<'a>, String> {
    let start_time = std::time::Instant::now();

    let headings = extract_headings_with_attributes(env, content)?;
    let links = extract_links_with_attributes(env, content)?;
    let code_blocks = extract_code_blocks_enhanced(env, content)?;
    let tasks = extract_tasks_enhanced(env, content)?;
    let jsonld_islands = extract_jsonld_islands(env, content)?;

    // Check for polyglot content
    let polyglot = detect_polyglot_document(content);

    let processing_time = start_time.elapsed().as_micros() as u64;

    let mut result = HashMap::new();
    result.insert("headings".to_string(), headings);
    result.insert("links".to_string(), links);
    result.insert("code_blocks".to_string(), code_blocks);
    result.insert("tasks".to_string(), tasks);
    result.insert("jsonld_islands".to_string(), jsonld_islands);
    result.insert(
        "processing_time_us".to_string(),
        processing_time.encode(env),
    );

    if let Some(poly) = polyglot {
        result.insert("polyglot_detected".to_string(), true.encode(env));
        result.insert("polyglot_language".to_string(), poly.language.encode(env));
    }

    Ok(result.encode(env))
}

fn parse_with_memory_context<'a>(
    env: Env<'a>,
    content: &str,
    context: &Mem8Context,
) -> Result<Term<'a>, String> {
    // Enhanced parsing with mem8 wave context
    let mut result = HashMap::new();

    // Parse standard markdown
    let standard_result = parse_markdown_content(env, content, &[])?;

    // Add memory context influence
    let wave_influence = calculate_wave_context_influence(&context.wave_grid, content);
    let consciousness_level = context.consciousness.awareness_level;

    result.insert("standard_parse".to_string(), standard_result);
    result.insert("wave_influence".to_string(), wave_influence.encode(env));
    result.insert(
        "consciousness_level".to_string(),
        consciousness_level.encode(env),
    );

    Ok(result.encode(env))
}

fn extract_headings_with_attributes<'a>(env: Env<'a>, content: &str) -> Result<Term<'a>, String> {
    let mut headings = Vec::new();
    let mut current_line = 1usize;

    let mut options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);

    let parser = Parser::new_ext(content, options);

    let mut in_heading = false;
    let mut heading_level = 1u32;
    let mut heading_text = String::new();
    let mut heading_start_line = 1usize;

    for event in parser {
        match event {
            Event::Start(Tag::Heading(level, _fragment_id, _classes)) => {
                in_heading = true;
                heading_level = match level {
                    HeadingLevel::H1 => 1,
                    HeadingLevel::H2 => 2,
                    HeadingLevel::H3 => 3,
                    HeadingLevel::H4 => 4,
                    HeadingLevel::H5 => 5,
                    HeadingLevel::H6 => 6,
                };
                heading_text.clear();
                heading_start_line = current_line;
            }
            Event::End(Tag::Heading(_, _, _)) => {
                if in_heading {
                    // Parse inline attributes if present
                    let (clean_text, attributes) = parse_inline_attributes(&heading_text);

                    let mut heading_map = HashMap::new();
                    heading_map.insert("level".to_string(), heading_level.encode(env));
                    heading_map.insert("text".to_string(), clean_text.encode(env));
                    heading_map.insert("line".to_string(), heading_start_line.encode(env));

                    if !attributes.is_empty() {
                        let attr_map: HashMap<String, Term> = attributes
                            .into_iter()
                            .map(|(k, v)| (k, encode_attribute_value(env, v)))
                            .collect();
                        heading_map.insert("attributes".to_string(), attr_map.encode(env));
                    }

                    // Generate stable ID
                    let stable_id = generate_heading_stable_id(&clean_text, heading_level);
                    heading_map.insert("stable_id".to_string(), stable_id.encode(env));

                    headings.push(heading_map.encode(env));
                    in_heading = false;
                }
            }
            Event::Text(text) => {
                if in_heading {
                    heading_text.push_str(&text);
                }
                current_line += text.chars().filter(|&c| c == '\n').count();
            }
            Event::SoftBreak | Event::HardBreak => {
                if in_heading {
                    heading_text.push(' ');
                }
                current_line += 1;
            }
            _ => {}
        }
    }

    Ok(headings.encode(env))
}

fn extract_links_with_attributes<'a>(env: Env<'a>, content: &str) -> Result<Term<'a>, String> {
    let mut links = Vec::new();
    let mut line = 1usize;

    let mut options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);

    let parser = Parser::new_ext(content, options);
    let mut link_text = String::new();
    let mut in_link = false;

    for event in parser {
        match event {
            Event::Start(Tag::Link(_link_type, _dest_url, _title)) => {
                in_link = true;
                link_text.clear();
            }
            Event::End(Tag::Link(_link_type, dest_url, title)) => {
                if in_link {
                    // Check for content-addressed links (SHA-256 hashes)
                    let is_content_addressed = is_sha256_hash(&dest_url);

                    // Parse inline attributes if present
                    let (clean_text, attributes) = parse_inline_attributes(&link_text);

                    let mut link_map = HashMap::new();
                    link_map.insert("text".to_string(), clean_text.encode(env));
                    link_map.insert("url".to_string(), dest_url.to_string().encode(env));
                    link_map.insert("line".to_string(), line.encode(env));
                    link_map.insert(
                        "content_addressed".to_string(),
                        is_content_addressed.encode(env),
                    );

                    if !title.is_empty() {
                        link_map.insert("title".to_string(), title.to_string().encode(env));
                    }

                    if !attributes.is_empty() {
                        let attr_map: HashMap<String, Term> = attributes
                            .into_iter()
                            .map(|(k, v)| (k, encode_attribute_value(env, v)))
                            .collect();
                        link_map.insert("attributes".to_string(), attr_map.encode(env));
                    }

                    links.push(link_map.encode(env));
                    in_link = false;
                }
            }
            Event::Text(text) => {
                if in_link {
                    link_text.push_str(&text);
                }
                line += text.chars().filter(|&c| c == '\n').count();
            }
            Event::SoftBreak | Event::HardBreak => {
                line += 1;
            }
            _ => {}
        }
    }

    Ok(links.encode(env))
}

fn extract_code_blocks_enhanced<'a>(env: Env<'a>, content: &str) -> Result<Term<'a>, String> {
    let mut code_blocks = Vec::new();
    let mut current_line = 1usize;
    let mut in_code_block = false;
    let mut current_code = String::new();
    let mut current_language: Option<String> = None;
    let mut code_start_line = 1usize;

    let mut options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);

    let parser = Parser::new_ext(content, options);

    for event in parser {
        match event {
            Event::Start(Tag::CodeBlock(kind)) => {
                in_code_block = true;
                current_language = match kind {
                    CodeBlockKind::Fenced(lang) => {
                        if lang.is_empty() {
                            None
                        } else {
                            Some(lang.to_string())
                        }
                    }
                    CodeBlockKind::Indented => None,
                };
                code_start_line = current_line;
                current_code.clear();
            }
            Event::End(Tag::CodeBlock(_)) => {
                if in_code_block {
                    let mut code_map = HashMap::new();

                    let language = current_language
                        .clone()
                        .unwrap_or_else(|| "unknown".to_string());
                    code_map.insert("language".to_string(), language.encode(env));
                    code_map.insert("content".to_string(), current_code.clone().encode(env));
                    code_map.insert("line".to_string(), code_start_line.encode(env));

                    // Detect special markdown-ld languages
                    let is_jsonld = matches!(
                        language.as_str(),
                        "json-ld" | "jsonld" | "application/ld+json"
                    );
                    let is_mem8 = language == "mem8";
                    let is_mq2 = language == "mq2";

                    code_map.insert("is_jsonld".to_string(), is_jsonld.encode(env));
                    code_map.insert("is_mem8".to_string(), is_mem8.encode(env));
                    code_map.insert("is_mq2".to_string(), is_mq2.encode(env));

                    // Extract polyglot artifacts from code blocks
                    if let Some(artifact_type) = detect_code_block_artifact(&current_code) {
                        code_map.insert("artifact_type".to_string(), artifact_type.encode(env));
                    }

                    code_blocks.push(code_map.encode(env));
                    in_code_block = false;
                }
            }
            Event::Text(text) => {
                if in_code_block {
                    current_code.push_str(&text);
                }
                current_line += text.chars().filter(|&c| c == '\n').count();
            }
            Event::SoftBreak | Event::HardBreak => {
                if in_code_block {
                    current_code.push('\n');
                }
                current_line += 1;
            }
            _ => {}
        }
    }

    Ok(code_blocks.encode(env))
}

fn extract_tasks_enhanced<'a>(env: Env<'a>, content: &str) -> Result<Term<'a>, String> {
    let mut tasks = Vec::new();
    let mut line_num = 1usize;

    for line in content.lines() {
        let trimmed = line.trim();
        if let Some(task) = parse_task_line(trimmed, line_num) {
            tasks.push(encode_task_item(env, task));
        }
        line_num += 1;
    }

    Ok(tasks.encode(env))
}

fn extract_jsonld_islands<'a>(env: Env<'a>, content: &str) -> Result<Term<'a>, String> {
    let mut islands = Vec::new();

    // Extract JSON-LD from frontmatter
    if let Some(frontmatter) = extract_frontmatter(content) {
        if let Some(jsonld) = extract_jsonld_from_frontmatter(&frontmatter) {
            islands.push(create_jsonld_island(env, jsonld, 1, "frontmatter"));
        }
    }

    // Extract JSON-LD from code fences
    let _code_blocks = extract_code_blocks_enhanced(env, content)?;
    // This would iterate through code blocks and find JSON-LD ones

    Ok(islands.encode(env))
}

// Polyglot detection
fn detect_polyglot_document(content: &str) -> Option<PolyglotDocument> {
    let mut max_score = 0.0f32;
    let mut best_match: Option<String> = None;
    let mut artifacts = Vec::new();

    // Check each detector
    for detector in POLYGLOT_DETECTORS.iter() {
        let primary_matches = detector.primary_pattern.find_iter(content).count();
        let secondary_matches = detector.secondary_pattern.find_iter(content).count();

        let score = (primary_matches as f32 * 2.0) + (secondary_matches as f32 * 0.5);

        if score > max_score && score > 2.0 {
            max_score = score;
            best_match = Some(detector.language.clone());

            // Extract artifacts for this language
            artifacts = extract_artifacts_for_language(content, &detector.language);
        }
    }

    if let Some(language) = best_match {
        Some(PolyglotDocument {
            language,
            artifacts,
            metadata: HashMap::new(),
            concealment: extract_all_concealment(content),
        })
    } else {
        None
    }
}

fn extract_artifacts_for_language(content: &str, language: &str) -> Vec<Artifact> {
    let mut artifacts = Vec::new();
    let mut line_num = 1usize;

    match language {
        "dockerfile" => {
            for line in content.lines() {
                if line.trim_start().to_uppercase().starts_with("FROM") {
                    artifacts.push(Artifact {
                        artifact_type: "dockerfile".to_string(),
                        content: line.to_string(),
                        language: Some("dockerfile".to_string()),
                        line_start: line_num,
                        line_end: line_num,
                    });
                }
                line_num += 1;
            }
        }
        "kubernetes" => {
            // Extract YAML blocks that look like k8s
            if content.contains("apiVersion:") && content.contains("kind:") {
                artifacts.push(Artifact {
                    artifact_type: "kubernetes".to_string(),
                    content: content.to_string(),
                    language: Some("yaml".to_string()),
                    line_start: 1,
                    line_end: content.lines().count(),
                });
            }
        }
        "bash" => {
            for line in content.lines() {
                if line.trim_start().starts_with("#!/bin/bash")
                    || line.trim_start().starts_with("#!/bin/sh")
                {
                    artifacts.push(Artifact {
                        artifact_type: "executable".to_string(),
                        content: content.to_string(),
                        language: Some("bash".to_string()),
                        line_start: 1,
                        line_end: content.lines().count(),
                    });
                    break;
                }
                line_num += 1;
            }
        }
        _ => {}
    }

    artifacts
}

// Character concealment functions
fn extract_all_concealment(content: &str) -> ConcealmentData {
    ConcealmentData {
        zero_width_chars: extract_zero_width_chars(content),
        content_addressed_links: extract_content_addressed_links(content),
        whitespace_patterns: extract_whitespace_patterns(content),
        html_comments: extract_html_comments(content),
    }
}

fn extract_zero_width_chars(content: &str) -> Vec<u8> {
    let mut zero_width_data = Vec::new();

    for ch in content.chars() {
        if ZERO_WIDTH_CHARS.contains(&ch) {
            // Convert zero-width char to data bit
            let index = ZERO_WIDTH_CHARS.iter().position(|&c| c == ch).unwrap_or(0);
            zero_width_data.push(index as u8);
        }
    }

    zero_width_data
}

fn encode_zero_width_data(data: &str) -> String {
    let mut result = String::new();

    for byte in data.bytes() {
        let char_index = (byte % ZERO_WIDTH_CHARS.len() as u8) as usize;
        result.push(ZERO_WIDTH_CHARS[char_index]);
    }

    result
}

fn decode_zero_width_data(data: &[u8]) -> Result<String, String> {
    // Simple decode - in reality would need proper base64 or similar
    let decoded: Vec<u8> = data
        .iter()
        .map(|&b| {
            if b < ZERO_WIDTH_CHARS.len() as u8 {
                b + 32
            } else {
                b
            }
        })
        .collect();

    String::from_utf8(decoded).map_err(|e| format!("UTF-8 decode error: {}", e))
}

fn extract_content_addressed_links(content: &str) -> Vec<String> {
    lazy_static! {
        static ref SHA256_REGEX: Regex = Regex::new(r"\[([^\]]+)\]\(([a-f0-9]{64})\)").unwrap();
    }

    SHA256_REGEX
        .captures_iter(content)
        .map(|cap| cap.get(2).unwrap().as_str().to_string())
        .collect()
}

fn extract_whitespace_patterns(content: &str) -> Vec<u8> {
    // Extract patterns from trailing whitespace
    let mut patterns = Vec::new();

    for line in content.lines() {
        let trailing_spaces = line.len() - line.trim_end().len();
        if trailing_spaces > 0 {
            patterns.push(trailing_spaces as u8);
        }
    }

    patterns
}

fn extract_html_comments(content: &str) -> Vec<String> {
    lazy_static! {
        static ref COMMENT_REGEX: Regex = Regex::new(r"<!-- polyglot:([^:]+):([^-]+) -->").unwrap();
    }

    COMMENT_REGEX
        .captures_iter(content)
        .map(|cap| cap.get(2).unwrap().as_str().to_string())
        .collect()
}

// RFC 8785 JSON Canonicalization Scheme
fn json_canonicalize(json_str: &str) -> Result<String, String> {
    // Parse JSON
    let value: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("JSON parse error: {}", e))?;

    // Convert to canonical form (JCS)
    canonicalize_json_value(&value)
}

fn canonicalize_json_value(value: &serde_json::Value) -> Result<String, String> {
    match value {
        serde_json::Value::Null => Ok("null".to_string()),
        serde_json::Value::Bool(b) => Ok(b.to_string()),
        serde_json::Value::Number(n) => Ok(n.to_string()),
        serde_json::Value::String(s) => Ok(format!("\"{}\"", escape_json_string(s))),
        serde_json::Value::Array(arr) => {
            let items: Result<Vec<_>, _> = arr.iter().map(canonicalize_json_value).collect();
            Ok(format!("[{}]", items?.join(",")))
        }
        serde_json::Value::Object(obj) => {
            let mut keys: Vec<_> = obj.keys().collect();
            keys.sort();

            let items: Result<Vec<_>, String> = keys
                .iter()
                .map(|k| {
                    let key = format!("\"{}\"", escape_json_string(k));
                    let value = canonicalize_json_value(obj.get(*k).unwrap())?;
                    Ok(format!("{}:{}", key, value))
                })
                .collect();
            Ok(format!("{{{}}}", items?.join(",")))
        }
    }
}

fn escape_json_string(s: &str) -> String {
    s.chars()
        .map(|c| match c {
            '"' => "\\\"".to_string(),
            '\\' => "\\\\".to_string(),
            '\n' => "\\n".to_string(),
            '\r' => "\\r".to_string(),
            '\t' => "\\t".to_string(),
            c if c.is_control() => format!("\\u{:04x}", c as u32),
            c => c.to_string(),
        })
        .collect()
}

// Stable ID generation
fn generate_stable_chunk_id(heading_path: &[String], block_index: u32, text: &str) -> String {
    let normalized_text = normalize_text_for_hash(text);
    let text_hash = sha256_hash(&normalized_text);

    let payload = serde_json::json!({
        "heading_path": heading_path,
        "block_index": block_index,
        "text_hash": text_hash
    });

    let canonical = json_canonicalize(&payload.to_string()).unwrap_or_default();
    let chunk_hash = sha256_hash(&canonical);
    chunk_hash[..12].to_string()
}

fn generate_heading_stable_id(text: &str, level: u32) -> String {
    let slug = create_heading_slug(text);
    format!("h{}-{}", level, slug)
}

fn create_heading_slug(text: &str) -> String {
    text.to_lowercase()
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == ' ' || *c == '-')
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join("-")
}

fn normalize_text_for_hash(text: &str) -> String {
    text.lines()
        .map(|line| line.trim_end())
        .collect::<Vec<_>>()
        .join("\n")
        .trim_end()
        .to_string()
}

fn sha256_hash(data: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data.as_bytes());
    format!("{:x}", hasher.finalize())
}

// Attribute object mini-grammar parser
#[derive(Debug, Clone)]
enum AttributeValue {
    String(String),
    Number(f64),
    Boolean(bool),
    List(Vec<AttributeValue>),
    Object(HashMap<String, AttributeValue>),
}

fn parse_attribute_object_mini_grammar(
    attr_str: &str,
    strict: bool,
) -> Result<HashMap<String, AttributeValue>, String> {
    let mut result = HashMap::new();

    // Simple key=value parser for now
    let pairs = attr_str.split_whitespace();

    for pair in pairs {
        if let Some((key, value)) = pair.split_once('=') {
            let parsed_value = parse_attribute_value(value, strict)?;
            result.insert(key.to_string(), parsed_value);
        }
    }

    Ok(result)
}

fn parse_attribute_value(value: &str, _strict: bool) -> Result<AttributeValue, String> {
    // Remove quotes if present
    let value = if value.starts_with('"') && value.ends_with('"') {
        &value[1..value.len() - 1]
    } else {
        value
    };

    // Try parsing as number
    if let Ok(n) = value.parse::<f64>() {
        return Ok(AttributeValue::Number(n));
    }

    // Try parsing as boolean
    if let Ok(b) = value.parse::<bool>() {
        return Ok(AttributeValue::Boolean(b));
    }

    // Default to string
    Ok(AttributeValue::String(value.to_string()))
}

fn encode_attribute_value<'a>(env: Env<'a>, value: AttributeValue) -> Term<'a> {
    match value {
        AttributeValue::String(s) => s.encode(env),
        AttributeValue::Number(n) => n.encode(env),
        AttributeValue::Boolean(b) => b.encode(env),
        AttributeValue::List(list) => {
            let encoded_list: Vec<Term> = list
                .into_iter()
                .map(|v| encode_attribute_value(env, v))
                .collect();
            encoded_list.encode(env)
        }
        AttributeValue::Object(obj) => {
            let encoded_obj: HashMap<String, Term> = obj
                .into_iter()
                .map(|(k, v)| (k, encode_attribute_value(env, v)))
                .collect();
            encoded_obj.encode(env)
        }
    }
}

// Inline attributes parsing
fn parse_inline_attributes(text: &str) -> (String, HashMap<String, AttributeValue>) {
    lazy_static! {
        static ref ATTR_REGEX: Regex = Regex::new(r"\s*\{([^}]+)\}\s*$").unwrap();
    }

    if let Some(captures) = ATTR_REGEX.captures(text) {
        let clean_text = ATTR_REGEX.replace(text, "").trim().to_string();
        let attr_str = captures.get(1).unwrap().as_str();

        let attributes = parse_attribute_object_mini_grammar(attr_str, false).unwrap_or_default();

        (clean_text, attributes)
    } else {
        (text.to_string(), HashMap::new())
    }
}

// Helper functions
fn is_sha256_hash(s: &str) -> bool {
    s.len() == 64 && s.chars().all(|c| c.is_ascii_hexdigit())
}

fn detect_code_block_artifact(content: &str) -> Option<String> {
    if content.contains("FROM ") && content.contains("RUN ") {
        Some("dockerfile".to_string())
    } else if content.contains("apiVersion:") && content.contains("kind:") {
        Some("kubernetes".to_string())
    } else if content.contains("resource ") && content.contains("provider ") {
        Some("terraform".to_string())
    } else {
        None
    }
}

fn parse_task_line(line: &str, line_num: usize) -> Option<TaskItem> {
    if line.starts_with("- [ ]") || line.starts_with("* [ ]") {
        Some(TaskItem {
            completed: false,
            text: line[5..].trim().to_string(),
            line: line_num,
        })
    } else if line.starts_with("- [x]") || line.starts_with("* [x]") {
        Some(TaskItem {
            completed: true,
            text: line[5..].trim().to_string(),
            line: line_num,
        })
    } else {
        None
    }
}

#[derive(Debug, Clone)]
struct TaskItem {
    completed: bool,
    text: String,
    line: usize,
}

fn encode_task_item<'a>(env: Env<'a>, task: TaskItem) -> Term<'a> {
    let mut task_map = HashMap::new();
    task_map.insert("completed".to_string(), task.completed.encode(env));
    task_map.insert("text".to_string(), task.text.encode(env));
    task_map.insert("line".to_string(), task.line.encode(env));
    task_map.encode(env)
}

fn extract_frontmatter(content: &str) -> Option<String> {
    if content.starts_with("---\n") {
        if let Some(end) = content[4..].find("\n---\n") {
            return Some(content[4..end + 4].to_string());
        }
    }
    None
}

fn extract_jsonld_from_frontmatter(frontmatter: &str) -> Option<String> {
    // Parse YAML and extract JSON-LD context
    // Simplified for now
    if frontmatter.contains("@context") {
        Some(frontmatter.to_string())
    } else {
        None
    }
}

fn create_jsonld_island<'a>(env: Env<'a>, content: String, line: usize, source: &str) -> Term<'a> {
    let mut island = HashMap::new();
    island.insert("content".to_string(), content.encode(env));
    island.insert("line".to_string(), line.encode(env));
    island.insert("source".to_string(), source.encode(env));
    island.encode(env)
}

// Mem8 integration
fn create_default_mem8_context() -> Mem8Context {
    Mem8Context {
        wave_grid: Arc::new(Mutex::new(WaveGrid {
            width: 64,
            height: 64,
            depth: 256,
            grid: vec![None; 64 * 64 * 256],
            noise_floor: 0.1,
        })),
        consciousness: ConsciousnessState {
            attention_weights: HashMap::new(),
            active_memories: Vec::new(),
            awareness_level: 0.5,
        },
        memory_index: MemIndex {
            version: "1.0.0".to_string(),
            blocks: HashMap::new(),
            projects: HashMap::new(),
        },
    }
}

fn calculate_wave_context_influence(_wave_grid: &Arc<Mutex<WaveGrid>>, content: &str) -> f32 {
    // Simplified wave influence calculation
    let word_count = content.split_whitespace().count() as f32;
    let influence = (word_count / 1000.0).min(1.0) * 0.5;
    influence
}

rustler::init!("Elixir.MarkdownLd.Native");
