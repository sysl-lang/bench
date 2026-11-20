


generic
   Max_String_Length : Positive;
package String_Fragments is

   subtype Fragment is String (1 .. Max_String_Length);

   function To_Fragment (Source : String) return Fragment;
   function Null_Fragment return Fragment;
   function "=" (Left, Right: Fragment) return Boolean;

end String_Fragments;
