! The Computer Language Benchmarks Game
! https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
!
! Original, written for this benchmark: the Game has no Fortran k-nucleotide
! (Fortran's standard library has no hash table). It mirrors the Game's
! fastest C program, knucleotide.gcc, contributed by Jeremy Zerfas: each
! oligonucleotide is a 2k-bit code rolled one base at a time, counted in an
! open-addressing hash table of 64-bit keys and 32-bit counts with the C
! program's hash, key xor key >> 7, and the seven tables are counted at once,
! one OpenMP section each, their text printed in order afterwards. The hash
! table is ffhash (ffhash_inc.f90 beside this file), a Fortran library
! modelled on the C program's khash.h.

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

! ffhash instantiated for 2k-bit codes and counts, as the C program
! instantiates khash: KHASH_INIT(oligonucleotide, uint64_t, uint32_t, ...).
module oligonucleotide_table
  use iso_fortran_env, only: int32, int64
  implicit none
#define FFH_KEY_TYPE integer(int64)
#define FFH_VAL_TYPE integer(int32)
#define FFH_CUSTOM_HASH_FUNCTION
#include "ffhash_inc.f90"

  ! The C program's CUSTOM_HASH_FUNCTION(key): key ^ key >> 7.
  pure function hash_function(key) result(hash)
    integer(int64), intent(in) :: key
    integer(int32) :: hash
    hash = int(ieor(key, shiftr(key, 7)), int32)
  end function hash_function
end module oligonucleotide_table

module oligonucleotides
  use iso_fortran_env, only: int8, int32, int64
  use oligonucleotide_table, only: ffh_t
  implicit none

contains

  ! Counts every oligonucleotide of length k in seq into h, as the C
  ! program's generate_Frequencies_For_Desired_Length_Oligonucleotides does.
  subroutine count_all(seq, k, h)
    integer(int8), intent(in) :: seq(:)
    integer, intent(in) :: k
    type(ffh_t), intent(inout) :: h
    integer(int64) :: code, mask
    integer(int32) :: ix, before
    integer :: i

    mask = shiftl(1_int64, 2 * k) - 1
    code = 0
    do i = 1, k - 1
       code = ior(iand(shiftl(code, 2), mask), int(seq(i), int64))
    end do
    do i = k, size(seq)
       code = ior(iand(shiftl(code, 2), mask), int(seq(i), int64))
       before = h%n_keys_stored
       call h%store_key(code, ix)
       if (h%n_keys_stored /= before) then
          h%vals(ix) = 1
       else
          h%vals(ix) = h%vals(ix) + 1
       end if
    end do
  end subroutine count_all

end module oligonucleotides

program knucleotide
  use iso_fortran_env, only: int8, int32, int64
  use iso_c_binding, only: c_size_t, c_long
  use posix_read
  use oligonucleotide_table, only: ffh_t
  use oligonucleotides
  implicit none

  integer, parameter :: CHUNK = 1048576
  integer(int8), parameter :: EOL = 10, GT = iachar('>', int8)
  character(len=*), parameter :: three = '>THREE'
  character(len=4), parameter :: letters = 'ACGT'

  type text
     character(len=:), allocatable :: text
  end type text

  integer(int8), allocatable :: input(:), seq(:), w(:)
  type(text) :: results(7)
  integer(int8) :: code_of(-128:127)
  integer(c_long) :: got
  integer :: n, i, j, nseq

  code_of = 0
  code_of(iachar('a')) = 0; code_of(iachar('A')) = 0
  code_of(iachar('c')) = 1; code_of(iachar('C')) = 1
  code_of(iachar('g')) = 2; code_of(iachar('G')) = 2
  code_of(iachar('t')) = 3; code_of(iachar('T')) = 3

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

  ! Find the line that starts the third sequence, and encode the sequence
  ! up to the next title (or the end) as 2-bit codes.
  i = 1
  do while (i <= n)
     if (i + len(three) - 1 <= n) then
        if (all(input(i:i+len(three)-1) == [(iachar(three(j:j), int8), j = 1, len(three))])) exit
     end if
     do while (i <= n)
        if (input(i) == EOL) exit
        i = i + 1
     end do
     i = i + 1
  end do
  do while (i <= n)
     if (input(i) == EOL) exit
     i = i + 1
  end do
  i = i + 1

  allocate(seq(n))
  nseq = 0
  do while (i <= n)
     if (input(i) == GT) exit
     if (input(i) /= EOL) then
        nseq = nseq + 1
        seq(nseq) = code_of(input(i))
     end if
     i = i + 1
  end do
  deallocate(input)

  ! The seven tables are counted at once, one OpenMP section each, as the
  ! C program does; each section's text is printed in order after.
  !$omp parallel sections
  !$omp section
  call write_frequencies(seq(1:nseq), 1, results(1)%text)
  !$omp section
  call write_frequencies(seq(1:nseq), 2, results(2)%text)
  !$omp section
  call write_count(seq(1:nseq), 'GGT', results(3)%text)
  !$omp section
  call write_count(seq(1:nseq), 'GGTA', results(4)%text)
  !$omp section
  call write_count(seq(1:nseq), 'GGTATT', results(5)%text)
  !$omp section
  call write_count(seq(1:nseq), 'GGTATTTTAATT', results(6)%text)
  !$omp section
  call write_count(seq(1:nseq), 'GGTATTTTAATTTATAGT', results(7)%text)
  !$omp end parallel sections

  do i = 1, size(results)
     write(*, '(a)', advance='no') results(i)%text
  end do

contains

  ! Every oligonucleotide of length k with its percentage, most frequent
  ! first, then by code, as lines of text in res.
  subroutine write_frequencies(seq, k, res)
    integer(int8), intent(in) :: seq(:)
    integer, intent(in) :: k
    character(len=:), allocatable, intent(out) :: res
    type(ffh_t) :: h
    integer(int64), allocatable :: keys(:)
    integer(int32), allocatable :: counts(:)
    integer :: i, j, m, best, total
    integer(int64) :: tk, code
    integer(int32) :: tc
    character(len=k) :: name
    character(len=64) :: line

    call count_all(seq, k, h)
    ! The table's entries as arrays, as the C program copies them out.
    allocate(keys(h%n_keys_stored), counts(h%n_keys_stored))
    m = 0
    do i = 0, h%n_buckets - 1
       if (h%valid_index(i)) then
          m = m + 1
          keys(m) = h%keys(i)
          counts(m) = h%vals(i)
       end if
    end do
    ! At most 16 entries: a selection sort by count, then by code.
    do i = 1, m - 1
       best = i
       do j = i + 1, m
          if (counts(j) > counts(best) .or. &
              (counts(j) == counts(best) .and. keys(j) < keys(best))) best = j
       end do
       tk = keys(i); keys(i) = keys(best); keys(best) = tk
       tc = counts(i); counts(i) = counts(best); counts(best) = tc
    end do
    total = size(seq) - k + 1
    res = ''
    do i = 1, m
       code = keys(i)
       do j = k, 1, -1
          name(j:j) = letters(iand(code, 3_int64) + 1:iand(code, 3_int64) + 1)
          code = shiftr(code, 2)
       end do
       ! The C program divides in single precision.
       write(line, '(a," ",f0.3)') name, 100.0 * real(counts(i)) / real(total)
       res = res // trim(line) // achar(10)
    end do
    res = res // achar(10)
  end subroutine write_frequencies

  ! The number of times the oligonucleotide s occurs, as a line of text in res.
  subroutine write_count(seq, s, res)
    integer(int8), intent(in) :: seq(:)
    character(len=*), intent(in) :: s
    character(len=:), allocatable, intent(out) :: res
    character(len=64) :: line
    type(ffh_t) :: h
    integer(int64) :: code
    integer(int32) :: ix
    integer :: i, count

    call count_all(seq, len(s), h)
    code = 0
    do i = 1, len(s)
       code = ior(shiftl(code, 2), int(code_of(iachar(s(i:i))), int64))
    end do
    ix = h%get_index(code)
    count = 0
    if (ix >= 0) count = h%vals(ix)
    write(line, '(i0,a,a)') count, achar(9), s
    res = trim(line) // achar(10)
  end subroutine write_count

end program knucleotide
