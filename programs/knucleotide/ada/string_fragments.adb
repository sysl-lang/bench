

with Ada.Unchecked_Conversion;

package body String_Fragments is

   Bytes_Per_Word : constant := 4;
   type Uns is mod 2**(8 * Bytes_Per_Word);
   for Uns'Size use 8 * Bytes_Per_Word;
   subtype Str is String (1 .. Bytes_Per_Word);

   function Null_Fragment return Fragment is
   begin
      return Fragment'(1 .. Max_String_Length => '*');
   end Null_Fragment;


   function To_Uns is new Ada.Unchecked_Conversion (Str, Uns);

   function "=" (Left, Right: Fragment) return Boolean is
      Strt : Integer := 1;
      Fnsh : Integer := Bytes_Per_Word;
      Last : constant Integer := Left'Last;
   begin
      if Last /= Right'Last then
         return False;
      end if;

      loop
         exit when Fnsh > Last;
         if To_Uns (Left(Strt..Fnsh)) /= To_Uns (Right(Strt..Fnsh)) then
            return False;
         end if;
         Strt := Strt + Bytes_Per_Word;
         Fnsh := Fnsh + Bytes_Per_Word;
      end loop;

      for I in Strt .. Last loop
         if Left(I) /= Right(I) then
            return False;
         end if;
      end loop;
      return True;
   end "=";


   function To_Fragment (Source : String) return Fragment is
      Result : Fragment;
   begin
      if Source'Length /= Max_String_Length then
         raise Constraint_Error;
      end if;
      Result (1 .. Source'Length) := Source;
      return Result;
   end To_Fragment;

end String_Fragments;
