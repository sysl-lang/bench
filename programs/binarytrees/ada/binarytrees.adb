--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program contributed by Kevin Carson.

with Ada.Command_Line;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;

procedure Binarytrees is
   type Tree_Node;
   type Tree_Access is access Tree_Node;
   type Tree_Node is record
      Left, Right : Tree_Access;
   end record;

   procedure Free is new Ada.Unchecked_Deallocation (Tree_Node, Tree_Access);

   function New_Tree_Node (Left, Right : Tree_Access) return Tree_Access is
   begin
      return new Tree_Node'(Left => Left, Right => Right);
   end New_Tree_Node;

   function Item_Check (Tree : Tree_Access) return Long_Integer is
   begin
      if Tree.Left = null then
         return 1;
      else
         return 1 + Item_Check (Tree.Left) + Item_Check (Tree.Right);
      end if;
   end Item_Check;

   function Bottom_Up_Tree (Depth : Natural) return Tree_Access is
   begin
      if Depth > 0 then
         return New_Tree_Node (Bottom_Up_Tree (Depth - 1), Bottom_Up_Tree (Depth - 1));
      else
         return New_Tree_Node (null, null);
      end if;
   end Bottom_Up_Tree;

   procedure Delete_Tree (Tree : in out Tree_Access) is
   begin
      if Tree.Left /= null then
         Delete_Tree (Tree.Left);
         Delete_Tree (Tree.Right);
      end if;
      Free (Tree);
   end Delete_Tree;

   function Img (V : Long_Integer) return String is
      Text : constant String := Long_Integer'Image (V);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Img;

   N              : constant Natural := Natural'Value (Ada.Command_Line.Argument (1));
   Min_Depth      : constant Natural := 4;
   Max_Depth      : constant Natural := (if Min_Depth + 2 > N then Min_Depth + 2 else N);
   Stretch_Depth  : constant Natural := Max_Depth + 1;
   Stretch_Tree   : Tree_Access;
   Long_Lived     : Tree_Access;
   Temp_Tree      : Tree_Access;
   Depth          : Natural;
   Iterations     : Long_Integer;
   Check          : Long_Integer;
begin
   Stretch_Tree := Bottom_Up_Tree (Stretch_Depth);
   Ada.Text_IO.Put_Line
     ("stretch tree of depth " & Img (Long_Integer (Stretch_Depth)) & ASCII.HT
      & " check: " & Img (Item_Check (Stretch_Tree)));
   Delete_Tree (Stretch_Tree);

   Long_Lived := Bottom_Up_Tree (Max_Depth);

   Depth := Min_Depth;
   while Depth <= Max_Depth loop
      Iterations := 2 ** (Max_Depth - Depth + Min_Depth);
      Check := 0;
      for I in 1 .. Iterations loop
         Temp_Tree := Bottom_Up_Tree (Depth);
         Check := Check + Item_Check (Temp_Tree);
         Delete_Tree (Temp_Tree);
      end loop;
      Ada.Text_IO.Put_Line
        (Img (Iterations) & ASCII.HT & " trees of depth " & Img (Long_Integer (Depth))
         & ASCII.HT & " check: " & Img (Check));
      Depth := Depth + 2;
   end loop;

   Ada.Text_IO.Put_Line
     ("long lived tree of depth " & Img (Long_Integer (Max_Depth)) & ASCII.HT
      & " check: " & Img (Item_Check (Long_Lived)));
end Binarytrees;
