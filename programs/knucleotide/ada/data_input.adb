
with Ada.Strings.Maps.Constants;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;
with Line_IO;
with Ada.Unchecked_Deallocation;

package body Data_Input is

   use Ada.Strings;
   UnixLF : constant String := String'(1 => ASCII.LF);
   package LIO is new Line_IO (UnixLF);

   Data_Buffer : Unbounded.Unbounded_String := Unbounded.Null_Unbounded_String;

   Section_Marker : constant Character := '>';
   Section        : constant String    := Section_Marker & "THREE";

   --  Read next data section - until EOF oder a line beginning with > is found.

   type String_Access is access String;
   procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);

   procedure Read_Section is
      Buffer     : String_Access;
      Read_First : Natural;
      Read_Last  : Natural;
   begin
      Buffer := new String (1 .. 1024 * 1024 * 16);
      Get_Data : loop
         Read_First := Buffer'First;
         Read_Last  := Buffer'First - 1;
         -- fill Buffer and append to Data_Buffer when filled
         loop
            declare
               Line : String renames LIO.Get_Line;
            begin
               Read_Last := Read_First + Line'Length - 1;
               if Read_Last >= Buffer'Last then
                  Unbounded.Append
                    (Data_Buffer, New_Item => Buffer(1 .. Read_First - 1));
                  Unbounded.Append (Data_Buffer, New_Item => Line);
                  exit;
               end if;
               Buffer (Read_First .. Read_Last) := Line;
            end;
            exit Get_Data when Buffer (Read_First) = Section_Marker;
            Read_First := Read_Last + 1;
         end loop;
      end loop Get_Data;
      Unbounded.Append (Data_Buffer, Buffer (1 .. Read_Last));
      Free (Buffer);
   exception
      when Ada.IO_Exceptions.End_Error =>
         Unbounded.Append (Data_Buffer, Buffer (1 .. Read_Last));
         Free (Buffer);
   end Read_Section;


   --  Skip data on Standard_Input until ">THREE" is found

   procedure Skip_To_Section is
   begin
      loop
         declare
            Line : constant String := LIO.Get_Line;
         begin
            exit when Line(1) = Section(1)
              and then Line(Section'Range) = Section;
         end;
      end loop;
   end Skip_To_Section;


   function Read return String is
   begin
      Skip_To_Section;
      Read_Section;

      Unbounded.Translate
        (Source => Data_Buffer,
         Mapping => Maps.Constants.Upper_Case_Map);

      return Unbounded.To_String (Data_Buffer);
   end Read;

end Data_Input;
