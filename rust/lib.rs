use geom::*;
use wasm_bindgen::prelude::*;

// When the `wee_alloc` feature is enabled, use `wee_alloc` as the global
// allocator.
#[cfg(feature = "wee_alloc")]
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

#[wasm_bindgen]
extern "C" {
    fn alert(s: &str);
}

#[wasm_bindgen]
pub fn greet() {
    alert("Hello!");
}

/// Mirrors the structure of 'ts/data/spatial.ts'
#[wasm_bindgen]
#[derive(Copy, Clone)]
pub struct Point3 {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl Point3 {
    pub fn zero() -> Self {
        Self {
            x: 0.,
            y: 0.,
            z: 0.,
        }
    }
}

impl From<geom::Point3> for Point3 {
    fn from([x, y, z]: geom::Point3) -> Self {
        Self { x, y, z }
    }
}

/// A _surface_ spatial object consisting of a bunch of triangles.
///
/// This object is meant to be fed into the `Viewer` object.
/// Since it will usually be transferred across the network, it is optimised for space.
/// It consists of an array of 'points' (x,y,z coordinates as 32-bit floats), an array of 'faces'
/// (32-bit indices of p1,p2,p3), and a translation `Point3`.
///
/// The points are 32-bit to save on space. The translation point is recommended to be the lower
/// AABB point. Each point will be translated like so:
/// `translate` + `(x,y,z)`
#[wasm_bindgen]
pub struct TriangleMeshSurface {
    points: Vec<f32>,
    indices: Vec<u32>,
    pub translate: Point3,
}

#[wasm_bindgen]
impl TriangleMeshSurface {
    pub fn empty() -> Self {
        TriangleMeshSurface {
            points: Vec::new(),
            indices: Vec::new(),
            translate: Point3::zero(),
        }
    }

    /// Fills `self` by deserializing a vulcan 00t triangulation.
    ///
    /// If this fails, `self` is unchanged.
    pub fn from_vulcan_00t(&mut self, data: &[u8]) -> Result<(), String> {
        let tri = geom::io::trimesh::from_vulcan_00t(data).map_err(|e| e.to_string())?;
        let translate = tri.aabb().origin;
        let (points, indices) = tri.decompose();

        self.translate = translate.into();
        self.points = points
            .into_iter()
            .flat_map(|p| p.sub(translate).map(|x| x as f32))
            .collect();
        self.indices = indices
            .into_iter()
            .flat_map(|(a, b, c)| [a, b, c])
            .collect();

        Ok(())
    }
}
