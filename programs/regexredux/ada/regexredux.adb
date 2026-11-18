--  regex-redux, written for this suite after the Benchmarks Game's programs:
--  GNAT's own regular-expression package, GNAT.Regpat (a compiled
--  backtracking matcher with Perl syntax). One thread.

with Ada.Text_IO;         use Ada.Text_IO;
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Unchecked_Deallocation;
with GNAT.OS_Lib;
with GNAT.Regpat;         use GNAT.Regpat;

procedure Regexredux is
   type String_Access is access String;
   procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);

   type Text is record
      Data : String_Access;
      Last : Natural := 0;
   end record;

   procedure Append (T : in out Text; S : String) is
   begin
      if T.Last + S'Length > T.Data'Length then
         declare
            Size   : Natural := T.Data'Length;
            Bigger : String_Access;
         begin
            while T.Last + S'Length > Size loop
               Size := 2 * Size;
            end loop;
            Bigger := new String (1 .. Size);
            Bigger (1 .. T.Last) := T.Data (1 .. T.Last);
            Free (T.Data);
            T.Data := Bigger;
         end;
      end if;
      T.Data (T.Last + 1 .. T.Last + S'Length) := S;
      T.Last := T.Last + S'Length;
   end Append;

   --  Every match of Pattern in Src, replaced by With_Text, appended to Dst.
   procedure Replace (Pattern : String; Src : String; With_Text : String; Dst : in out Text) is
      Re  : constant Pattern_Matcher := Compile (Pattern);
      M   : Match_Array (0 .. 0);
      Pos : Positive := Src'First;
   begin
      while Pos <= Src'Last loop
         Match (Re, Src, M, Data_First => Pos);
         exit when M (0) = No_Match;
         Append (Dst, Src (Pos .. M (0).First - 1));
         Append (Dst, With_Text);
         Pos := M (0).Last + 1;
      end loop;
      Append (Dst, Src (Pos .. Src'Last));
   end Replace;

   function Count (Pattern : String; Src : String) return Natural is
      Re  : constant Pattern_Matcher := Compile (Pattern);
      M   : Match_Array (0 .. 0);
      Pos : Positive := Src'First;
      N   : Natural := 0;
   begin
      while Pos <= Src'Last loop
         Match (Re, Src, M, Data_First => Pos);
         exit when M (0) = No_Match;
         N := N + 1;
         Pos := M (0).Last + 1;
      end loop;
      return N;
   end Count;

   type Pattern_Text is access constant String;

   Variants : constant array (1 .. 9) of Pattern_Text :=
     (new String'("agggtaaa|tttaccct"),
      new String'("[cgt]gggtaaa|tttaccc[acg]"),
      new String'("a[act]ggtaaa|tttacc[agt]t"),
      new String'("ag[act]gtaaa|tttac[agt]ct"),
      new String'("agg[act]taaa|ttta[agt]cct"),
      new String'("aggg[acg]aaa|ttt[cgt]ccct"),
      new String'("agggt[cgt]aa|tt[acg]accct"),
      new String'("agggta[cgt]a|t[acg]taccct"),
      new String'("agggtaa[cgt]|[acg]ttaccct"));

   type Subst is record
      Pattern, Replacement : Pattern_Text;
   end record;

   Substs : constant array (1 .. 5) of Subst :=
     ((new String'("tHa[Nt]"), new String'("<4>")),
      (new String'("aND|caN|Ha[DS]|WaS"), new String'("<3>")),
      (new String'("a[NSt]|BY"), new String'("<2>")),
      (new String'("<[^>]*>"), new String'("|")),
      (new String'("\|[^|][^|]*\|"), new String'("-")));

   Input    : Text := (new String (1 .. 2**20), 0);
   Sequence : Text := (new String (1 .. 2**20), 0);
   Pre      : Text;
   Post     : Text;
begin
   --  Read the whole of standard input.
   loop
      if Input.Last = Input.Data'Length then
         declare
            Bigger : constant String_Access := new String (1 .. 2 * Input.Data'Length);
         begin
            Bigger (1 .. Input.Last) := Input.Data (1 .. Input.Last);
            Free (Input.Data);
            Input.Data := Bigger;
         end;
      end if;
      declare
         Got : constant Integer :=
           GNAT.OS_Lib.Read (GNAT.OS_Lib.Standin, Input.Data (Input.Last + 1)'Address,
                             Input.Data'Length - Input.Last);
      begin
         exit when Got <= 0;
         Input.Last := Input.Last + Got;
      end;
   end loop;

   --  `.` does not match a newline in GNAT.Regpat, as in Perl. (A newline is
   --  written `\n`: Compile refuses a literal one with "junk on end".)
   Replace (">.*\n|\n", Input.Data (1 .. Input.Last), "", Sequence);

   for V of Variants loop
      Put_Line (V.all & Natural'Image (Count (V.all, Sequence.Data (1 .. Sequence.Last))));
   end loop;

   Pre := (new String'(Sequence.Data (1 .. Sequence.Last)), Sequence.Last);
   for S of Substs loop
      Post := (new String (1 .. Pre.Last + Pre.Last / 2 + 1), 0);
      Replace (S.Pattern.all, Pre.Data (1 .. Pre.Last), S.Replacement.all, Post);
      Free (Pre.Data);
      Pre := Post;
   end loop;

   New_Line;
   Put (Input.Last, Width => 0);
   New_Line;
   Put (Sequence.Last, Width => 0);
   New_Line;
   Put (Pre.Last, Width => 0);
   New_Line;
end Regexredux;
