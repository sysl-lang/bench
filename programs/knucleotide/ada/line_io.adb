

with Ada.Streams.Stream_IO;

package body Line_IO is

   use Ada.Streams;

   Stdin : Stream_IO.File_Type;

   -- Types etc., status variables, and the buffer.

   BUFSIZ: constant := 8_192;
   pragma Assert(Character'Size = Stream_Element'Size);

   SL : constant Natural := Separator_Sequence'Length;

   subtype Extended_Buffer_Index is Positive range 1 .. BUFSIZ + SL;
   subtype Buffer_Index is Extended_Buffer_Index
     range Extended_Buffer_Index'First .. Extended_Buffer_Index'Last - SL;
   subtype Extended_Bytes_Index is Stream_Element_Offset
     range 1 .. Stream_Element_Offset(Extended_Buffer_Index'Last);
   subtype Bytes_Index is Extended_Bytes_Index
     range Extended_Bytes_Index'First
     .. (Extended_Bytes_Index'Last - Stream_Element_Offset(SL));

   subtype Buffer_Data is String(Extended_Buffer_Index);
   subtype Buffer_Bytes is Stream_Element_Array(Extended_Bytes_Index);

   Buffer : Buffer_Data;
   Bytes  : Buffer_Bytes;
   for Bytes'Address use Buffer'Address;
   pragma Import (Ada, Bytes);

   -- start of next substring and last valid character in buffer
   Position : Natural range 0 .. Extended_Buffer_Index'Last;
   Last     : Natural range 0 .. Buffer_Index'Last;
   End_Of_Input : Boolean;

   function Get_Line return String is

      procedure Reload is
         --  fill Buffer with bytes available
         Last_Filled : Stream_Element_Offset;
      begin
         if Last < Buffer_Index'Last then
            raise Stream_IO.End_Error;
         end if;
         Stream_IO.Read(Stdin,
           Item => Bytes(Bytes_Index),
           Last => Last_Filled);
         Last := Natural(Last_Filled);
         Position := 1;
         Buffer(Last + 1 .. Last + SL) := Separator_Sequence;
      end Reload;


      function Separator_Position return Natural is
         --   index of next Separator_Sequence (may be sentinel)
         pragma Inline(Separator_Position);
         K : Extended_Buffer_Index := Position;
      begin
         while Buffer(K) /= Separator_Sequence(1) loop
            K := K + 1;
         end loop;
         return K;
      end Separator_Position;


      Next_Separator : Natural range 0 .. Extended_Buffer_Index'Last;
   begin  -- Get_Line

      if End_Of_Input then
         raise Stream_IO.End_Error;
      end if;

      Next_Separator := Separator_Position;

      if Next_Separator > Last then
         declare
            Result : constant String := Buffer(Position .. Last);
            subtype XString is String (1 .. Last - Position + 1);
         begin
            begin
               Reload;
               return XString(Result) & Get_Line;
            exception
               when Stream_IO.End_Error =>
                  End_Of_Input := True;
                  return XString(Result);
            end;
         end;
      else
         declare
            Result : String renames Buffer(Position .. Next_Separator - 1);
            subtype XString is String (1 .. Next_Separator - Position);
         begin
            Position := Next_Separator + SL;
            return XString (Result);
         end;
      end if;

      raise Program_Error;
   end Get_Line;


begin
   Stream_IO.Open (Stdin,
     Mode => Stream_IO.In_File,
     Name => "/dev/stdin");

   Buffer(Buffer_Index'Last + 1 .. Buffer'Last) := Separator_Sequence;
   Position := Buffer_Index'Last + 1;
   Last := Buffer_Index'Last;
   End_Of_Input := False;
end Line_IO;
