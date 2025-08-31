#[cfg(target_arch = "x86_64")]
use std::arch::x86_64::*;

// SIMD optimizations for text processing - help Codex out with the performance layer

#[cfg(target_arch = "x86_64")]
pub fn word_count_avx2(text: &str) -> usize {
    if !is_x86_feature_detected!("avx2") {
        return text.split_whitespace().count();
    }
    
    unsafe { word_count_avx2_impl(text) }
}

#[cfg(target_arch = "x86_64")]
unsafe fn word_count_avx2_impl(text: &str) -> usize {
    let bytes = text.as_bytes();
    let len = bytes.len();
    
    if len < 32 {
        return text.split_whitespace().count();
    }
    
    let mut count = 0;
    let mut i = 0;
    let mut in_word = false;
    
    // Process 32 bytes at a time with AVX2
    while i + 32 <= len {
        let chunk = _mm256_loadu_si256(bytes.as_ptr().add(i) as *const __m256i);
        
        // Check for whitespace characters (space, tab, newline, etc.)
        let spaces = _mm256_cmpeq_epi8(chunk, _mm256_set1_epi8(b' ' as i8));
        let tabs = _mm256_cmpeq_epi8(chunk, _mm256_set1_epi8(b'\t' as i8));
        let newlines = _mm256_cmpeq_epi8(chunk, _mm256_set1_epi8(b'\n' as i8));
        let returns = _mm256_cmpeq_epi8(chunk, _mm256_set1_epi8(b'\r' as i8));
        
        // Combine all whitespace checks
        let whitespace = _mm256_or_si256(_mm256_or_si256(spaces, tabs), _mm256_or_si256(newlines, returns));
        
        // Get mask of non-whitespace characters
        let non_whitespace = _mm256_xor_si256(whitespace, _mm256_set1_epi8(-1));
        let mask = _mm256_movemask_epi8(non_whitespace);
        
        // Count word boundaries (transitions from whitespace to non-whitespace)
        let prev_mask = if i == 0 { 0 } else {
            let prev_byte = bytes[i - 1];
            if prev_byte == b' ' || prev_byte == b'\t' || prev_byte == b'\n' || prev_byte == b'\r' {
                0
            } else {
                0x80000000u32
            }
        };
        
        // Find word starts (non-whitespace after whitespace)
        let shifted = (mask << 1) | prev_mask;
        let word_starts = mask & !shifted;
        count += word_starts.count_ones() as usize;
        
        i += 32;
    }
    
    // Handle remaining bytes
    let remaining = &text[i..];
    for ch in remaining.chars() {
        match ch {
            ' ' | '\t' | '\n' | '\r' => {
                if in_word {
                    in_word = false;
                }
            }
            _ => {
                if !in_word {
                    count += 1;
                    in_word = true;
                }
            }
        }
    }
    
    count
}

#[cfg(target_arch = "x86_64")]
pub fn find_markdown_patterns_simd(text: &str, patterns: &[&str]) -> Vec<(usize, String)> {
    if !is_x86_feature_detected!("avx2") {
        return find_patterns_fallback(text, patterns);
    }
    
    unsafe { find_patterns_avx2(text, patterns) }
}

#[cfg(target_arch = "x86_64")]
unsafe fn find_patterns_avx2(text: &str, patterns: &[&str]) -> Vec<(usize, String)> {
    let mut matches = Vec::new();
    let bytes = text.as_bytes();
    let len = bytes.len();
    
    // Look for markdown patterns like ##, -, *, [, ], etc.
    for pattern in patterns {
        let pattern_bytes = pattern.as_bytes();
        if pattern_bytes.is_empty() { continue; }
        
        let first_byte = pattern_bytes[0];
        let pattern_len = pattern_bytes.len();
        
        if pattern_len == 1 {
            // Single character patterns - use SIMD to find all occurrences
            let needle = _mm256_set1_epi8(first_byte as i8);
            let mut i = 0;
            
            while i + 32 <= len {
                let haystack = _mm256_loadu_si256(bytes.as_ptr().add(i) as *const __m256i);
                let cmp = _mm256_cmpeq_epi8(haystack, needle);
                let mask = _mm256_movemask_epi8(cmp);
                
                if mask != 0 {
                    for bit in 0..32 {
                        if (mask & (1 << bit)) != 0 {
                            matches.push((i + bit, pattern.to_string()));
                        }
                    }
                }
                i += 32;
            }
            
            // Handle remaining bytes
            for j in i..len {
                if bytes[j] == first_byte {
                    matches.push((j, pattern.to_string()));
                }
            }
        } else {
            // Multi-character patterns - first find potential starts with SIMD
            let needle = _mm256_set1_epi8(first_byte as i8);
            let mut i = 0;
            
            while i + 32 <= len {
                let haystack = _mm256_loadu_si256(bytes.as_ptr().add(i) as *const __m256i);
                let cmp = _mm256_cmpeq_epi8(haystack, needle);
                let mask = _mm256_movemask_epi8(cmp);
                
                if mask != 0 {
                    for bit in 0..32 {
                        if (mask & (1 << bit)) != 0 {
                            let pos = i + bit;
                            if pos + pattern_len <= len && &bytes[pos..pos + pattern_len] == pattern_bytes {
                                matches.push((pos, pattern.to_string()));
                            }
                        }
                    }
                }
                i += 32;
            }
        }
    }
    
    matches.sort_by_key(|&(pos, _)| pos);
    matches
}

fn find_patterns_fallback(text: &str, patterns: &[&str]) -> Vec<(usize, String)> {
    let mut matches = Vec::new();
    
    for pattern in patterns {
        for (i, _) in text.match_indices(pattern) {
            matches.push((i, pattern.to_string()));
        }
    }
    
    matches.sort_by_key(|&(pos, _)| pos);
    matches
}

// Apple Silicon ARM NEON optimizations for when we're not on x86
#[cfg(target_arch = "aarch64")]
pub fn word_count_neon(text: &str) -> usize {
    // For now, fallback to standard implementation
    // Could implement NEON SIMD later for Apple Silicon
    text.split_whitespace().count()
}

#[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
pub fn word_count_simd(text: &str) -> usize {
    text.split_whitespace().count()
}

// Export the right function based on target architecture
#[cfg(target_arch = "x86_64")]
pub use word_count_avx2 as word_count_simd;

#[cfg(target_arch = "aarch64")]
pub use word_count_neon as word_count_simd;