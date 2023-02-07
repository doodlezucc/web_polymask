A polygon merging Dart library with web/SVG implementation, made to be used in **vector based drawing tools**.

You can play around with this package by visiting [Dungeon Club's sandbox](https://dungeonclub.net/game/sandbox) mode. Click the "*Fog of War*" button to enable a paint brush.

## Vector Based Drawing

You may be wondering how *painting on a canvas* is related to the union of polygons.

Generally speaking, a digital paint brush can be implemented either by storing and editing **a color for each pixel** or by managing a **set of vector shapes**. While the first approach is much easier to implement, it's also less performant and can take up a lot of data storage. Vector graphics on the other hand can be considered more "sustainable" because you never lose resolution, regardless of how far you zoom in, and because you store the *outline* of a polygonal shape instead of every pixel inside.

The most common vector graphics format [SVG](https://www.w3.org/TR/SVG2/) (as supported by all modern browsers) is able to display circles, rectangles and polygons on a website. When trying to outline a specific shape with any given list of points, polygons are the best option.

Painting hand drawn shapes on a vector based canvas works by continuously projecting a *brush outline* (e.g. a small circle) at your cursor position and merging it into the rest of your canvas. This means that everytime you move your cursor while drawing, a polygon resembling your brush is "added" to the canvas. However, instead of having thousands of independent overlapping shapes, a sophisticated algorithm is run to *merge new polygons into previous ones*. This way, canvases keep the lowest possible number of total polygons, implying the least possible amount of storage.

### Understanding the Problem at Hand

In order to compose an algorithm capable of merging polygons, it's important to know the "matter" and the "anti-matter", the **solid (_positive_)** and the **holes (_negative_)**. An **O** shape can only be created with 2 separate polygons: a *solid* one to make the outer radius and a fully enclosed *hole* to make the inner radius. Negative polygons are acting as "masks" and erase enclosed areas from solid polygons. 

Merging a polygon into others is not as trivial as "make a bridge between the two". For example, if you wanted to add a straight line and turn **O** into **Ø**, you are going to end up with **3 separate polygons**: the *positive* outline and 2 *negative* half circles.

You can think of polygon based drawings as being "scoped" with alternating pole: The root of your canvas is a negative foundation on which solid polygons can be placed. Each of your solid polygons can contain holes, which in turn can enclose another layer of solid shapes.

```py
# Polygonal drawing

       █ Ø ▣


# Tree of scopes

[-] ROOT
    
    [+] █ solid block
    
    [+] Ø outline
        [-] half circle (top left)
        [-] half circle (bottom right)
    
    [+] ▣ outer square
        [-] hole inside outer square
            [+] inner square
```

With this understanding in mind, have another go in [Dungeon Club's sandbox](https://dungeonclub.net/game/sandbox) mode using the "*Fog of War*" tool. You should find yourself constantly modifying, removing and creating new polygons on the fly. You may also inspect the live HTML code to see changes to the different layers of SVG elements which are puppeteered behind the scenes.