// Upstream C++ list.h. An element owns the rest of its list (`Box`), as C++'s destructor deletes
// `next`; `tail` passes borrowed elements, as C++ passes raw pointers it does not own. C++ stores
// the element's value as `std::any`; it is only ever an integer, never read.

use crate::benchmark::Benchmark;

struct Element {
    #[allow(dead_code)]
    val: i32,
    next: Option<Box<Element>>,
}

impl Element {
    fn new(v: i32) -> Element {
        Element { val: v, next: None }
    }

    fn length(&self) -> i32 {
        match &self.next {
            None => 1,
            Some(next) => 1 + next.length(),
        }
    }

    fn get_next(&self) -> Option<&Element> {
        self.next.as_deref()
    }

    fn set_next(&mut self, e: Option<Box<Element>>) {
        self.next = e;
    }
}

pub struct List;

impl List {
    fn make_list(&self, length: i32) -> Option<Box<Element>> {
        if length == 0 {
            return None;
        }
        let mut e = Box::new(Element::new(length));
        e.set_next(self.make_list(length - 1));
        Some(e)
    }

    fn is_shorter_than(&self, x: Option<&Element>, y: Option<&Element>) -> bool {
        let mut x_tail = x;
        let mut y_tail = y;

        while let Some(y_elem) = y_tail {
            let Some(x_elem) = x_tail else {
                return true;
            };
            x_tail = x_elem.get_next();
            y_tail = y_elem.get_next();
        }
        false
    }

    fn tail<'e>(
        &self,
        x: Option<&'e Element>,
        y: Option<&'e Element>,
        z: Option<&'e Element>,
    ) -> Option<&'e Element> {
        if self.is_shorter_than(y, x) {
            // `y` is shorter than `x`, so `x` is not empty (C++ dereferences it unchecked).
            let (xn, yn, zn) = (x.unwrap().get_next(), y.unwrap().get_next(), z.unwrap().get_next());
            return self.tail(self.tail(xn, y, z), self.tail(yn, z, x), self.tail(zn, x, y));
        }
        z
    }
}

impl Benchmark for List {
    type Result = i32;

    fn benchmark(&mut self) -> i32 {
        let x = self.make_list(15);
        let y = self.make_list(10);
        let z = self.make_list(6);

        let result = self.tail(x.as_deref(), y.as_deref(), z.as_deref());
        let l = result.unwrap().length();

        drop(x);
        drop(y);
        drop(z);
        l
    }

    fn verify_result(&mut self, result: i32) -> bool {
        10 == result
    }
}
