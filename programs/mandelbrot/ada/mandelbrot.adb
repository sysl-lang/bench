--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program contributed by Greg Buchholz.

with Ada.Command_Line;
with Ada.Streams;
with Ada.Text_IO;
with Ada.Text_IO.Text_Streams;
with Interfaces;

procedure Mandelbrot is
   use Interfaces;
   use type Ada.Streams.Stream_Element_Offset;

   W : constant Integer := Integer'Value (Ada.Command_Line.Argument (1));
   H : constant Integer := W;

   Iter  : constant := 50;
   Limit : constant Long_Float := 2.0;

   Out_Stream : constant Ada.Text_IO.Text_Streams.Stream_Access :=
     Ada.Text_IO.Text_Streams.Stream (Ada.Text_IO.Standard_Output);

   Row_Bytes : constant Ada.Streams.Stream_Element_Offset :=
     Ada.Streams.Stream_Element_Offset ((W + 7) / 8);
   Row       : Ada.Streams.Stream_Element_Array (1 .. Row_Bytes);
   Pos       : Ada.Streams.Stream_Element_Offset;

   Bit_Num  : Integer := 0;
   Byte_Acc : Unsigned_8 := 0;

   Zr, Zi, Cr, Ci, Tr, Ti : Long_Float;
   I : Integer;

   function Img (V : Integer) return String is
      Text : constant String := Integer'Image (V);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Img;
begin
   Ada.Text_IO.Put_Line ("P4");
   Ada.Text_IO.Put_Line (Img (W) & " " & Img (H));
   Ada.Text_IO.Flush;

   for Yi in 0 .. H - 1 loop
      Pos := 0;
      for Xi in 0 .. W - 1 loop
         Zr := 0.0;
         Zi := 0.0;
         Tr := 0.0;
         Ti := 0.0;
         Cr := 2.0 * Long_Float (Xi) / Long_Float (W) - 1.5;
         Ci := 2.0 * Long_Float (Yi) / Long_Float (H) - 1.0;

         I := 0;
         while I < Iter and then Tr + Ti <= Limit * Limit loop
            Zi := 2.0 * Zr * Zi + Ci;
            Zr := Tr - Ti + Cr;
            Tr := Zr * Zr;
            Ti := Zi * Zi;
            I := I + 1;
         end loop;

         Byte_Acc := Shift_Left (Byte_Acc, 1);
         if Tr + Ti <= Limit * Limit then
            Byte_Acc := Byte_Acc or 1;
         end if;

         Bit_Num := Bit_Num + 1;

         if Bit_Num = 8 then
            Pos := Pos + 1;
            Row (Pos) := Ada.Streams.Stream_Element (Byte_Acc);
            Byte_Acc := 0;
            Bit_Num := 0;
         elsif Xi = W - 1 then
            Byte_Acc := Shift_Left (Byte_Acc, 8 - W mod 8);
            Pos := Pos + 1;
            Row (Pos) := Ada.Streams.Stream_Element (Byte_Acc);
            Byte_Acc := 0;
            Bit_Num := 0;
         end if;
      end loop;
      Out_Stream.all.Write (Row (1 .. Pos));
   end loop;
end Mandelbrot;
