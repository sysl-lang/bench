// Upstream C++ som/dictionary.h and som/identity_dictionary.h: a chained hash table whose keys are
// objects compared by address and hashed by their `customHash()`, with power-of-two buckets that
// double and split when the size passes the capacity. C++'s `Dictionary` and `IdentityDictionary`
// match an entry identically (`_hash == h && _key == k`, a virtual `match` the subclass overrides
// with the same body), so here there is one type, named for the one C++ instantiates. As in C++,
// the dictionary does not own its keys; it owns its entries (and, in Rust, its values).

use std::ptr;

use super::vector::Vector;

pub trait CustomHash {
    fn custom_hash(&self) -> u32;
}

const INITIAL_CAPACITY: u32 = 16;

struct Entry<'k, K, V> {
    hash: u32,
    key: &'k K,
    value: V,
    next: Option<Box<Entry<'k, K, V>>>,
}

impl<'k, K, V> Entry<'k, K, V> {
    fn matches(&self, h: u32, k: &K) -> bool {
        self.hash == h && ptr::eq(self.key, k)
    }
}

type Bucket<'k, K, V> = Option<Box<Entry<'k, K, V>>>;

pub struct IdentityDictionary<'k, K, V> {
    buckets: Box<[Bucket<'k, K, V>]>,
    size: u32,
    capacity: u32,
}

fn new_buckets<'k, K, V>(capacity: u32) -> Box<[Bucket<'k, K, V>]> {
    std::iter::repeat_with(|| None).take(capacity as usize).collect()
}

impl<'k, K: CustomHash, V> IdentityDictionary<'k, K, V> {
    pub fn new() -> Self {
        IdentityDictionary::with_capacity(INITIAL_CAPACITY)
    }

    pub fn with_capacity(capacity: u32) -> Self {
        IdentityDictionary { buckets: new_buckets(capacity), size: 0, capacity }
    }

    pub fn get_size(&self) -> u32 {
        self.size
    }

    pub fn is_empty(&self) -> bool {
        self.size == 0
    }

    fn hash(key: &K) -> u32 {
        let h = key.custom_hash();
        h ^ (h >> 16)
    }

    pub fn contains_key(&self, key: &K) -> bool {
        let h = Self::hash(key);
        let mut e = self.get_bucket(h);

        while let Some(entry) = e {
            if entry.matches(h, key) {
                return true;
            }
            e = entry.next.as_deref();
        }
        false
    }

    pub fn at(&self, key: &K) -> Option<&V> {
        let h = Self::hash(key);
        let mut e = self.get_bucket(h);

        while let Some(entry) = e {
            if entry.matches(h, key) {
                return Some(&entry.value);
            }
            e = entry.next.as_deref();
        }
        None
    }

    pub fn at_put(&mut self, key: &'k K, value: V) {
        let h = Self::hash(key);
        let i = self.get_bucket_idx(h);

        match &mut self.buckets[i] {
            None => {
                self.buckets[i] = Some(Self::new_entry(key, value, h));
                self.size += 1;
            }
            Some(current) => {
                if Self::insert_bucket_entry(key, value, h, current) {
                    self.size += 1;
                }
            }
        }

        if self.size > self.capacity {
            self.resize();
        }
    }

    pub fn remove_all(&mut self) {
        for bucket in self.buckets.iter_mut() {
            *bucket = None;
        }
        self.size = 0;
    }

    pub fn get_keys(&self) -> Box<Vector<&'k K>> {
        let mut keys = Box::new(Vector::new());
        for bucket in self.buckets.iter() {
            let mut current = bucket.as_deref();
            while let Some(entry) = current {
                keys.append(entry.key);
                current = entry.next.as_deref();
            }
        }
        keys
    }

    fn new_entry(key: &'k K, value: V, hash: u32) -> Box<Entry<'k, K, V>> {
        Box::new(Entry { hash, key, value, next: None })
    }

    fn get_bucket_idx(&self, hash: u32) -> usize {
        ((self.capacity - 1) & hash) as usize
    }

    fn get_bucket(&self, hash: u32) -> Option<&Entry<'k, K, V>> {
        self.buckets[self.get_bucket_idx(hash)].as_deref()
    }

    /// Returns whether a new entry was added (C++ increments `_size` in place).
    fn insert_bucket_entry(key: &'k K, value: V, hash: u32, head: &mut Entry<'k, K, V>) -> bool {
        let mut current = head;

        loop {
            if current.matches(hash, key) {
                current.value = value;
                return false;
            }
            match current.next {
                None => {
                    current.next = Some(Self::new_entry(key, value, hash));
                    return true;
                }
                Some(ref mut next) => current = next,
            }
        }
    }

    fn resize(&mut self) {
        let old_capacity = self.capacity;
        self.capacity *= 2;
        let mut old_storage = std::mem::replace(&mut self.buckets, new_buckets(self.capacity));
        self.transfer_entries(&mut old_storage, old_capacity);
    }

    fn transfer_entries(&mut self, old_storage: &mut [Bucket<'k, K, V>], old_capacity: u32) {
        for i in 0..old_capacity as usize {
            if let Some(current) = old_storage[i].take() {
                if current.next.is_none() {
                    let idx = (current.hash & (old_capacity - 1)) as usize;
                    self.buckets[idx] = Some(current);
                } else {
                    self.split_bucket(old_capacity, i, current);
                }
            }
        }
    }

    fn split_bucket(&mut self, old_capacity: u32, idx: usize, head: Box<Entry<'k, K, V>>) {
        let mut lo_head: Bucket<'k, K, V> = None;
        let mut lo_tail = &mut lo_head;
        let mut hi_head: Bucket<'k, K, V> = None;
        let mut hi_tail = &mut hi_head;

        let mut current = Some(head);

        while let Some(mut entry) = current {
            current = entry.next.take();
            if (entry.hash & old_capacity) == 0 {
                lo_tail = &mut lo_tail.insert(entry).next;
            } else {
                hi_tail = &mut hi_tail.insert(entry).next;
            }
        }

        if lo_head.is_some() {
            self.buckets[idx] = lo_head;
        }
        if hi_head.is_some() {
            self.buckets[idx + old_capacity as usize] = hi_head;
        }
    }
}
