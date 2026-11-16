--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program contributed by Jeremy Zerfas. The counts
--  live in Ada.Containers.Hashed_Maps, keyed by the 2k-bit code of the
--  oligonucleotide with the C program's shift-and-xor hash.

with Ada.Containers;
with Ada.Containers.Generic_Array_Sort;
with Ada.Containers.Hashed_Maps;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Interfaces;

procedure Knucleotide is
   use Interfaces;
   use type Ada.Containers.Hash_Type;

   function Hash (Key : Unsigned_64) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type (Unsigned_64'(Key xor Shift_Right (Key, 7)) mod 2 ** 32));

   package Oligo_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Unsigned_64,
      Element_Type    => Unsigned_32,
      Hash            => Hash,
      Equivalent_Keys => "=");

   type Byte_Array is array (Natural range <>) of Unsigned_8;
   type Byte_Access is access Byte_Array;
   procedure Free is new Ada.Unchecked_Deallocation (Byte_Array, Byte_Access);

   type Element is record
      Key   : Unsigned_64;
      Value : Unsigned_32;
   end record;
   type Element_Array is array (Positive range <>) of Element;

   --  Elements with larger values come first; equal values order by key.
   function Before (Left, Right : Element) return Boolean is
     (if Left.Value /= Right.Value then Left.Value > Right.Value else Left.Key < Right.Key);

   procedure Sort is new Ada.Containers.Generic_Array_Sort
     (Index_Type   => Positive,
      Element_Type => Element,
      Array_Type   => Element_Array,
      "<"          => Before);

   --  A is 0, C is 1, G is 2, T is 3, in either case.
   Codes : constant array (0 .. 7) of Unsigned_8 := (0, 0, 0, 1, 3, 0, 0, 2);

   function Code_For_Nucleotide (C : Character) return Unsigned_8 is
     (Codes (Character'Pos (C) mod 8));

   Nucleotides : constant String := "ACGT";

   Poly     : Byte_Access := new Byte_Array (0 .. 1_048_575);
   Poly_Len : Natural := 0;

   package Long_IO is new Ada.Text_IO.Float_IO (Long_Float);

   function Frequency_Text (Percent : Long_Float) return String is
      Text : String (1 .. 32);
   begin
      Long_IO.Put (Text, Percent, Aft => 3, Exp => 0);
      for I in Text'Range loop
         if Text (I) /= ' ' then
            return Text (I .. Text'Last);
         end if;
      end loop;
      return Text;
   end Frequency_Text;

   function Img (V : Natural) return String is
      Text : constant String := Natural'Image (V);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Img;

   procedure Count_Into (Table : in out Oligo_Maps.Map; Length : Positive) is
      Key  : Unsigned_64 := 0;
      Mask : constant Unsigned_64 := Shift_Left (1, 2 * Length) - 1;
      Pos  : Oligo_Maps.Cursor;
      Fresh : Boolean;
   begin
      for I in 0 .. Length - 2 loop
         Key := (Shift_Left (Key, 2) and Mask) or Unsigned_64 (Poly (I));
      end loop;
      for I in Length - 1 .. Poly_Len - 1 loop
         Key := (Shift_Left (Key, 2) and Mask) or Unsigned_64 (Poly (I));
         Table.Insert (Key, 1, Pos, Fresh);
         if not Fresh then
            declare
               Count : Unsigned_32 renames Table.Reference (Pos).Element.all;
            begin
               Count := Count + 1;
            end;
         end if;
      end loop;
   end Count_Into;

   function Frequencies (Length : Positive) return String is
      Table  : Oligo_Maps.Map;
      Result : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Count_Into (Table, Length);

      declare
         Items : Element_Array (1 .. Natural (Table.Length));
         I     : Natural := 0;
      begin
         for Pos in Table.Iterate loop
            I := I + 1;
            Items (I) := (Oligo_Maps.Key (Pos), Oligo_Maps.Element (Pos));
         end loop;
         Table.Clear;
         Sort (Items);

         for E of Items loop
            declare
               Name : String (1 .. Length);
               Key  : Unsigned_64 := E.Key;
            begin
               for J in reverse Name'Range loop
                  Name (J) := Nucleotides (Natural (Key and 3) + 1);
                  Key := Shift_Right (Key, 2);
               end loop;
               --  The C program divides in single precision.
               Ada.Strings.Unbounded.Append
                 (Result,
                  Name & ' ' & Frequency_Text
                    (Long_Float (100.0 * Float (E.Value) / Float (Poly_Len - Length + 1)))
                  & ASCII.LF);
            end;
         end loop;
      end;
      return Ada.Strings.Unbounded.To_String (Result);
   end Frequencies;

   function Count_For (Oligo : String) return String is
      Table : Oligo_Maps.Map;
      Key   : Unsigned_64 := 0;
      Pos   : Oligo_Maps.Cursor;
      Count : Natural;
   begin
      Count_Into (Table, Oligo'Length);
      for C of Oligo loop
         Key := Shift_Left (Key, 2) or Unsigned_64 (Code_For_Nucleotide (C));
      end loop;
      Pos := Table.Find (Key);
      Count := (if Oligo_Maps.Has_Element (Pos) then Natural (Oligo_Maps.Element (Pos)) else 0);
      return Img (Count) & ASCII.HT & Oligo;
   end Count_For;

   Line : String (1 .. 4096);
   Last : Natural;
begin
   --  Find the start of the third polynucleotide.
   loop
      exit when Ada.Text_IO.End_Of_File;
      Ada.Text_IO.Get_Line (Line, Last);
      exit when Last >= 6 and then Line (1 .. 6) = ">THREE";
   end loop;

   --  Read and encode it.
   while not Ada.Text_IO.End_Of_File loop
      Ada.Text_IO.Get_Line (Line, Last);
      exit when Last > 0 and then Line (1) = '>';
      if Poly'Length - Poly_Len <= Last then
         declare
            Bigger : constant Byte_Access := new Byte_Array (0 .. 2 * Poly'Length - 1);
         begin
            Bigger (0 .. Poly_Len - 1) := Poly (0 .. Poly_Len - 1);
            Free (Poly);
            Poly := Bigger;
         end;
      end if;
      for K in 1 .. Last loop
         Poly (Poly_Len) := Code_For_Nucleotide (Line (K));
         Poly_Len := Poly_Len + 1;
      end loop;
   end loop;

   Ada.Text_IO.Put_Line (Frequencies (1));
   Ada.Text_IO.Put_Line (Frequencies (2));
   Ada.Text_IO.Put_Line (Count_For ("GGT"));
   Ada.Text_IO.Put_Line (Count_For ("GGTA"));
   Ada.Text_IO.Put_Line (Count_For ("GGTATT"));
   Ada.Text_IO.Put_Line (Count_For ("GGTATTTTAATT"));
   Ada.Text_IO.Put_Line (Count_For ("GGTATTTTAATTTATAGT"));
end Knucleotide;
