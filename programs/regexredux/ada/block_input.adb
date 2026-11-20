
with Ada.Streams.Stream_IO;
with Interfaces.C_Streams;

package body Block_Input is

   use Ada.Streams;

   cin : Stream_IO.File_Type;

   function Read return U.String_Access is
      use Interfaces.C_Streams;
      Items_To_Read : Stream_Element_Offset;
      Items_Read    : Stream_Element_Offset;
      Buffer        : U.String_Access;
   begin
      if fseek (stdin, 0, SEEK_END) /= -1 then
         Items_To_Read := Stream_Element_Offset (ftell (stdin));
         rewind (stdin);
         Buffer := new String (1 .. Positive (Items_To_Read));
         declare
            View : Stream_Element_Array (1 .. Items_To_Read);
            pragma Import (Ada, View);
            for View'Address use Buffer.all'Address;
         begin
            Stream_IO.Read (File => cin,
                            Item => View,
                            Last => Items_Read);
         end;
      end if;
      return Buffer;
   end Read;

   procedure Open_Stdin is
   begin
      Stream_IO.Open
        (File => cin,
         Mode => Stream_IO.In_File,
         Name => "/dev/stdin");
   end Open_Stdin;

   procedure Close_Stdin is
   begin
      Stream_IO.Close (cin);
   end Close_Stdin;

end Block_Input;
