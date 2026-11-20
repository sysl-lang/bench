
---------------------------
--  Stream I/O of lines --
---------------------------
generic
   Separator_Sequence : in String;  --  ends a line
package Line_IO is

   pragma Elaborate_Body;

   procedure Put_Line (Item : String) is null;
   -- not used in this program

   function Get_Line return String;

end Line_IO;
