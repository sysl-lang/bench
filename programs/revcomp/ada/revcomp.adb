--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program contributed by Bob W: each record is read
--  a line at a time, complemented through a table into a buffer filled from
--  its end, and written back out in lines of 60.

with GNAT.OS_Lib;
with Ada.Unchecked_Deallocation;

procedure Revcomp is
   type String_Access is access String;
   procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);

   --  Input is read from fd 0 in large blocks and output written to fd 1 in
   --  large blocks.
   In_Buf  : String (1 .. 65536);
   In_Pos  : Natural := 1;
   In_Len  : Natural := 0;
   Out_Buf : String (1 .. 65536);
   Out_Len : Natural := 0;

   function End_Of_File return Boolean is
   begin
      if In_Pos > In_Len then
         declare
            Got : constant Integer :=
              GNAT.OS_Lib.Read (GNAT.OS_Lib.Standin, In_Buf'Address, In_Buf'Length);
         begin
            In_Pos := 1;
            In_Len := Natural'Max (Got, 0);
         end;
      end if;
      return In_Pos > In_Len;
   end End_Of_File;

   --  Reads up to one line (at most Item'Length characters) into Item.
   procedure Get_Line (Item : out String; Last : out Natural) is
   begin
      Last := Item'First - 1;
      while Last < Item'Last and then not End_Of_File loop
         declare
            C : constant Character := In_Buf (In_Pos);
         begin
            In_Pos := In_Pos + 1;
            exit when C = ASCII.LF;
            Last := Last + 1;
            Item (Last) := C;
         end;
      end loop;
   end Get_Line;

   procedure Flush is
      Pos : Natural := 1;
      Got : Integer;
   begin
      while Pos <= Out_Len loop
         Got := GNAT.OS_Lib.Write (GNAT.OS_Lib.Standout, Out_Buf (Pos)'Address, Out_Len - Pos + 1);
         exit when Got <= 0;
         Pos := Pos + Got;
      end loop;
      Out_Len := 0;
   end Flush;

   procedure Put (S : String) is
   begin
      if Out_Len + S'Length > Out_Buf'Length then
         Flush;
      end if;
      Out_Buf (Out_Len + 1 .. Out_Len + S'Length) := S;
      Out_Len := Out_Len + S'Length;
   end Put;

   procedure New_Line is
   begin
      Put ((1 => ASCII.LF));
   end New_Line;

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

   if End_Of_File then
      raise Program_Error with "No input data";
   end if;
   Get_Line (Line, Last);
   if Last = 0 or else Line (1) /= '>' then
      raise Program_Error with "1st char not '>'";
   end if;

   while More loop
      Put (Line (1 .. Last));
      New_Line;
      Pr := Cap + 1;

      loop
         if End_Of_File then
            More := False;
            exit;
         end if;
         Get_Line (Line, Last);
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
            Put (Buf (Pr .. Pr + X - 1));
            New_Line;
            Pr := Pr + X;
         end;
      end loop;
   end loop;
   Flush;
end Revcomp;
