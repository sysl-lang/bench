--  The Computer Language Benchmarks Game
--  https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
--
--  A port to Ada of the C program by Drake Diedrich.

with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces;

procedure Fasta is
   use Interfaces;

   IM   : constant := 139968;
   IA   : constant := 3877;
   IC   : constant := 29573;
   Seed : Unsigned_32 := 42;

   function Fasta_Rand return Long_Float is
   begin
      Seed := (Seed * IA + IC) mod IM;
      return 1.0 * Long_Float (Seed) / Long_Float (IM);
   end Fasta_Rand;

   Linelen : constant := 60;

   Alu : constant String :=
     "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
     & "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
     & "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
     & "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
     & "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
     & "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
     & "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

   type Probabilities is array (Positive range <>) of Long_Float;

   Iub   : constant String := "acgtBDHKMNRSVWY";
   Iub_P : constant Probabilities (1 .. 15) :=
     (0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02);

   Homosapiens   : constant String := "acgt";
   Homosapiens_P : constant Probabilities (1 .. 4) :=
     (0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008);

   procedure Repeat_Fasta (Seq : String; N : Natural) is
      Len    : constant Natural := Seq'Length;
      Buffer : String (1 .. Len + Linelen);
      T      : Natural := 0;
      Whole  : constant Natural := N / Linelen;
   begin
      Buffer (1 .. Len) := Seq;
      Buffer (Len + 1 .. Len + Linelen) := Seq (Seq'First .. Seq'First + Linelen - 1);
      for I in 1 .. Whole loop
         declare
            Start : constant Natural := T mod Len + 1;
         begin
            Ada.Text_IO.Put (Buffer (Start .. Start + Linelen - 1));
            Ada.Text_IO.New_Line;
            T := T + Linelen;
         end;
      end loop;
      if N - T > 0 then
         declare
            Start : constant Natural := T mod Len + 1;
         begin
            Ada.Text_IO.Put (Buffer (Start .. Start + (N - T) - 1));
         end;
      end if;
      if N mod Linelen /= 0 then
         Ada.Text_IO.New_Line;
      end if;
   end Repeat_Fasta;

   --  Counting the probabilities below v is faster than stopping at the first
   --  one above it.
   function Linear_Lookup (P : Probabilities; V : Long_Float) return Positive is
      I : Positive := 1;
   begin
      for J in P'First .. P'Last - 1 loop
         if V > P (J) then
            I := I + 1;
         end if;
      end loop;
      return I;
   end Linear_Lookup;

   procedure Random_Fasta (Symb : String; Probability : Probabilities; N : Natural) is
      Len       : constant Natural := Symb'Length;
      P         : Probabilities (1 .. Len);
      Buffer    : String (1 .. Linelen);
      Remainder : Natural;
      V         : Long_Float;
   begin
      P (1) := Probability (Probability'First);
      for I in 2 .. Len loop
         P (I) := Probability (Probability'First + I - 1) + P (I - 1);
      end loop;

      for I in 1 .. N / Linelen loop
         for K in Buffer'Range loop
            V := Fasta_Rand;
            Buffer (K) := Symb (Symb'First + Linear_Lookup (P, V) - 1);
         end loop;
         Ada.Text_IO.Put (Buffer);
         Ada.Text_IO.New_Line;
      end loop;
      Remainder := N - (N / Linelen) * Linelen;
      for K in 1 .. Remainder loop
         V := Fasta_Rand;
         Buffer (K) := Symb (Symb'First + Linear_Lookup (P, V) - 1);
      end loop;
      Ada.Text_IO.Put (Buffer (1 .. Remainder));
      if N mod Linelen /= 0 then
         Ada.Text_IO.New_Line;
      end if;
   end Random_Fasta;

   N : constant Natural :=
     (if Ada.Command_Line.Argument_Count > 0
      then Natural'Value (Ada.Command_Line.Argument (1)) else 1000);
begin
   Ada.Text_IO.Put_Line (">ONE Homo sapiens alu");
   Repeat_Fasta (Alu, N * 2);

   Ada.Text_IO.Put_Line (">TWO IUB ambiguity codes");
   Random_Fasta (Iub, Iub_P, N * 3);

   Ada.Text_IO.Put_Line (">THREE Homo sapiens frequency");
   Random_Fasta (Homosapiens, Homosapiens_P, N * 5);
end Fasta;
