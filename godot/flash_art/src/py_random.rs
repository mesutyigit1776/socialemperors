//! The random generator of Python (the Mersenne Twister of the module
//! `random`), so that the import makes the same shop rotation as the server
//! (`random.seed(int)`) and the same mock villages as the Python importer
//! (`random.Random(str)`). The algorithms follow CPython 3.13
//! (Modules/_randommodule.c and Lib/random.py).

use sha2::{Digest, Sha512};

const N: usize = 624;
const M: usize = 397;

pub struct PyRandom {
    state: [u32; N],
    index: usize,
}

impl PyRandom {
    /// `random.seed(n)` for an int: all the bits of |n| are used.
    pub fn from_int(seed: i64) -> PyRandom {
        let value = seed.unsigned_abs();
        let mut key = vec![value as u32];
        if value >> 32 != 0 {
            key.push((value >> 32) as u32);
        }
        PyRandom::from_key(&key)
    }

    /// `random.seed(text)` (version 2): the seed is the int of the UTF-8
    /// bytes of the text followed by their SHA-512 digest, big-endian.
    pub fn from_text(text: &str) -> PyRandom {
        let mut bytes = text.as_bytes().to_vec();
        bytes.extend_from_slice(&Sha512::digest(text.as_bytes()));
        // The key is the int in 32-bit words, the lowest word first, without
        // the zero words above its highest bit.
        let mut key: Vec<u32> = bytes
            .rchunks(4)
            .map(|chunk| chunk.iter().fold(0u32, |word, &byte| (word << 8) | byte as u32))
            .collect();
        while key.len() > 1 && *key.last().unwrap() == 0 {
            key.pop();
        }
        PyRandom::from_key(&key)
    }

    fn from_key(key: &[u32]) -> PyRandom {
        let mut random = PyRandom { state: [0; N], index: N };
        random.init_genrand(19_650_218);
        let mut i = 1;
        let mut j = 0;
        for _ in 0..N.max(key.len()) {
            let previous = random.state[i - 1] ^ (random.state[i - 1] >> 30);
            random.state[i] = (random.state[i] ^ previous.wrapping_mul(1_664_525))
                .wrapping_add(key[j])
                .wrapping_add(j as u32);
            i += 1;
            j += 1;
            if i >= N {
                random.state[0] = random.state[N - 1];
                i = 1;
            }
            if j >= key.len() {
                j = 0;
            }
        }
        for _ in 0..N - 1 {
            let previous = random.state[i - 1] ^ (random.state[i - 1] >> 30);
            random.state[i] = (random.state[i] ^ previous.wrapping_mul(1_566_083_941)).wrapping_sub(i as u32);
            i += 1;
            if i >= N {
                random.state[0] = random.state[N - 1];
                i = 1;
            }
        }
        random.state[0] = 0x8000_0000;
        random
    }

    fn init_genrand(&mut self, seed: u32) {
        self.state[0] = seed;
        for i in 1..N {
            let previous = self.state[i - 1] ^ (self.state[i - 1] >> 30);
            self.state[i] = 1_812_433_253u32.wrapping_mul(previous).wrapping_add(i as u32);
        }
        self.index = N;
    }

    fn next_u32(&mut self) -> u32 {
        if self.index >= N {
            for k in 0..N {
                let y = (self.state[k] & 0x8000_0000) | (self.state[(k + 1) % N] & 0x7fff_ffff);
                let mut value = self.state[(k + M) % N] ^ (y >> 1);
                if y & 1 != 0 {
                    value ^= 0x9908_b0df;
                }
                self.state[k] = value;
            }
            self.index = 0;
        }
        let mut y = self.state[self.index];
        self.index += 1;
        y ^= y >> 11;
        y ^= (y << 7) & 0x9d2c_5680;
        y ^= (y << 15) & 0xefc6_0000;
        y ^ (y >> 18)
    }

    /// `random.random()`: a float in [0, 1) from 53 random bits.
    pub fn random(&mut self) -> f64 {
        let a = (self.next_u32() >> 5) as f64;
        let b = (self.next_u32() >> 6) as f64;
        (a * 67_108_864.0 + b) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// `random.getrandbits(k)` for k up to 63.
    fn getrandbits(&mut self, k: u32) -> u64 {
        if k <= 32 {
            return if k == 0 { 0 } else { (self.next_u32() >> (32 - k)) as u64 };
        }
        // The words come lowest first; the last word keeps its high bits.
        let low = self.next_u32() as u64;
        let high = (self.next_u32() >> (64 - k)) as u64;
        low | (high << 32)
    }

    /// `random._randbelow(n)`: an int in [0, n). Like Python, it takes
    /// random bits also for n = 1.
    pub fn randbelow(&mut self, n: u64) -> u64 {
        let k = 64 - n.leading_zeros();
        loop {
            let r = self.getrandbits(k);
            if r < n {
                return r;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::PyRandom;

    // Values from CPython 3.13.
    #[test]
    fn int_seed() {
        let mut random = PyRandom::from_int(42);
        assert_eq!(random.random(), 0.6394267984578837);
        assert_eq!(random.randbelow(10), 0);
    }

    #[test]
    fn text_seed() {
        let mut random = PyRandom::from_text("Pebble/4/2");
        assert_eq!(random.random(), 0.5374703445340503);
    }

    #[test]
    fn two_word_seed() {
        let mut random = PyRandom::from_int(98_765_432_101);
        assert_eq!(random.random(), 0.9360076686833543);
        assert_eq!(random.randbelow(1), 0);
        assert_eq!(random.randbelow(1000), 541);
    }
}
