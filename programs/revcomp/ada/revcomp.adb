--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program contributed by Bob W: each record is read
--  a line at a time, complemented through a table into a buffer filled from
--  its end, and written back out in lines of 60.

with Ada.Text_IO;
with Ada.Unchecked_Deallocation;

procedure Revcomp is
   type String_Access is access String;
   procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);

   Growth : constant := 12_777_888;

   --  The complement of each IUB code letter, in either case; NUL for any
   --  other character, which is dropped.
   Xtab : array (Character) of Character := (others => ASCII.NUL);

   procedure Map (From, To : Character) is
   begin
      Xtab (From) := To;
      Xtab (Character'Val (Character'Pos (From) + 32)) := To;
   end Map;

   Line : String (1 .. 1024);
   Last : Natural;

   Buf : String_Access := new String (1 .. 5200);
   Cap : Natural := 5200;
   Pr  : Natural;

   procedure Grow is
      New_Cap : constant Natural := Cap + Growth;
      New_Buf : constant String_Access := new String (1 .. New_Cap);
      Used    : constant Natural := Cap - Pr + 1;
   begin
      New_Buf (New_Cap - Used + 1 .. New_Cap) := Buf (Pr .. Cap);
      Free (Buf);
      Buf := New_Buf;
      Pr := New_Cap - Used + 1;
      Cap := New_Cap;
   end Grow;

   More : Boolean := True;
begin
   Map ('A', 'T');
   Map ('B', 'V');
   Map ('C', 'G');
   Map ('D', 'H');
   Map ('G', 'C');
   Map ('H', 'D');
   Map ('K', 'M');
   Map ('M', 'K');
   Map ('N', 'N');
   Map ('R', 'Y');
   Map ('S', 'S');
   Map ('T', 'A');
   Map ('V', 'B');
   Map ('W', 'W');
   Map ('Y', 'R');

   if Ada.Text_IO.End_Of_File then
      raise Program_Error with "No input data";
   end if;
   Ada.Text_IO.Get_Line (Line, Last);
   if Last = 0 or else Line (1) /= '>' then
      raise Program_Error with "1st char not '>'";
   end if;

   while More loop
      Ada.Text_IO.Put_Line (Line (1 .. Last));
      Pr := Cap + 1;

      loop
         if Ada.Text_IO.End_Of_File then
            More := False;
            exit;
         end if;
         Ada.Text_IO.Get_Line (Line, Last);
         exit when Last > 0 and then Line (1) = '>';

         if Pr - 1 <= Last + 1 then
            Grow;
         end if;
         for K in 1 .. Last loop
            declare
               C : constant Character := Xtab (Line (K));
            begin
               if C /= ASCII.NUL then
                  Pr := Pr - 1;
                  Buf (Pr) := C;
               end if;
            end;
         end loop;
      end loop;

      while Pr <= Cap loop
         declare
            X : constant Natural := Natural'Min (Cap - Pr + 1, 60);
         begin
            Ada.Text_IO.Put (Buf (Pr .. Pr + X - 1));
            Ada.Text_IO.New_Line;
            Pr := Pr + X;
         end;
      end loop;
   end loop;
end Revcomp;
