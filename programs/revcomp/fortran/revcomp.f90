! The Computer Language Benchmarks Game
! https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
!
! contributed by Andrei Jirnyi, modified from version by Steve Decker

module posix_read
  use iso_c_binding, only: c_int, c_size_t, c_long, c_int8_t
  implicit none
  interface
     ! POSIX read(2). Fortran cannot read a stream of unknown length in
     ! blocks: an end of file during a READ leaves every input item
     ! undefined, so the last, partial block would be lost.
     function c_read(fd, buf, count) bind(C, name='read') result(got)
       import :: c_int, c_size_t, c_long, c_int8_t
       integer(c_int), value :: fd
       integer(c_int8_t) :: buf(*)
       integer(c_size_t), value :: count
       integer(c_long) :: got
     end function c_read
  end interface
end module posix_read

program revcomp
  use iso_fortran_env, only: int8
  use iso_c_binding, only: c_size_t, c_long
  use posix_read
  implicit none

  integer(int8), parameter :: EOL = 10, GT = iachar('>', int8)
  integer, parameter :: LW = 60, CHUNK = 1048576

  integer(int8), dimension(:), allocatable :: input, seq, output, w
  integer(int8) :: comp(-128:127)
  integer(c_long) :: got
  integer :: out, n, i, start, k, nseq, nout, last, lines

  call make_table()

  ! Read all of standard input.
  allocate(input(4 * CHUNK))
  n = 0
  do
     if (n + CHUNK > size(input)) then
        allocate(w(2 * size(input)))
        w(1:n) = input(1:n)
        call move_alloc(w, input)
     end if
     got = c_read(0, input(n+1:), int(CHUNK, c_size_t))
     if (got <= 0) exit
     n = n + int(got)
  end do

  open(newunit=out, file='/dev/stdout', access='stream', form='unformatted', action='write')
  allocate(seq(n), output(n + n / LW + 2))

  i = 1
  do while (i <= n)
     ! The title line, written as it is.
     start = i
     do while (i <= n)
        if (input(i) == EOL) exit
        i = i + 1
     end do
     write(out) input(start:min(i, n))
     i = i + 1

     ! The sequence up to the next title, complemented through the table
     ! and stored from the end, so it reads reversed.
     k = size(seq) + 1
     do while (i <= n)
        if (input(i) == GT) exit
        if (comp(input(i)) /= 0) then
           k = k - 1
           seq(k) = comp(input(i))
        end if
        i = i + 1
     end do

     ! Re-wrapped at LW.
     nseq = size(seq) + 1 - k
     lines = nseq / LW
     nout = 0
     do start = k, k + (lines - 1) * LW, LW
        output(nout+1:nout+LW) = seq(start:start+LW-1)
        output(nout+LW+1) = EOL
        nout = nout + LW + 1
     end do
     last = nseq - lines * LW
     if (last > 0) then
        output(nout+1:nout+last) = seq(size(seq)-last+1:size(seq))
        output(nout+last+1) = EOL
        nout = nout + last + 1
     end if
     write(out) output(1:nout)
  end do
  close(out)

contains

  ! The complement of each letter, upper or lower case, as an upper-case
  ! letter; zero for every other byte, which is dropped.
  subroutine make_table()
    character(len=*), parameter :: from = 'ACGTUMRWSYKVHDBN'
    character(len=*), parameter :: to   = 'TGCAAKYWSRMBDHVN'
    integer :: j

    comp = 0
    do j = 1, len(from)
       comp(iachar(from(j:j))) = iachar(to(j:j), int8)
       comp(iachar(from(j:j)) + 32) = iachar(to(j:j), int8)
    end do
  end subroutine make_table

end program revcomp
