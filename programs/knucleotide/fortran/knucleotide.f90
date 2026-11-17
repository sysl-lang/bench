! The Computer Language Benchmarks Game
! https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
!
! Contributed by Jeremy Zerfas

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

module oligonucleotides
  use iso_fortran_env, only: int8, int32, int64
  use stdlib_hashmaps, only: open_hashmap_type
  use stdlib_hashmap_wrappers, only: key_type, set
  implicit none

  ! stdlib's map holds class(*) values, so it maps each oligonucleotide's
  ! code to its index in keys and counts.
  type counter
     type(open_hashmap_type) :: map
     integer(int64), allocatable :: keys(:)
     integer(int32), allocatable :: counts(:)
     integer :: n = 0
  end type counter

contains

  ! The C program's hash, key xor key >> 7, of the 2k-bit code that the
  ! key holds as eight bytes.
  pure function kmer_hasher(key) result(hash)
    type(key_type), intent(in) :: key
    integer(int32) :: hash
    integer(int64) :: code

    code = transfer(key%value, code)
    hash = int(ieor(code, shiftr(code, 7)), int32)
  end function kmer_hasher

  ! Counts every oligonucleotide of length k in seq into c.
  subroutine count_all(seq, k, c)
    integer(int8), intent(in) :: seq(:)
    integer, intent(in) :: k
    type(counter), intent(out) :: c
    integer(int64) :: code, mask
    integer :: i
    type(key_type) :: key
    class(*), allocatable :: other
    logical :: exists

    call c%map%init(kmer_hasher, slots_bits=10)
    allocate(c%keys(1024), c%counts(1024))
    mask = shiftl(1_int64, 2 * k) - 1
    code = 0
    do i = 1, k - 1
       code = ior(iand(shiftl(code, 2), mask), int(seq(i), int64))
    end do
    do i = k, size(seq)
       code = ior(iand(shiftl(code, 2), mask), int(seq(i), int64))
       call set(key, transfer(code, [0_int8], 8))
       call c%map%get_other_data(key, other, exists)
       if (exists) then
          select type (other)
          type is (integer)
             c%counts(other) = c%counts(other) + 1
          end select
       else
          c%n = c%n + 1
          if (c%n > size(c%keys)) call grow(c)
          c%keys(c%n) = code
          c%counts(c%n) = 1
          call c%map%map_entry(key, c%n)
       end if
    end do
  end subroutine count_all

  subroutine grow(c)
    type(counter), intent(inout) :: c
    integer(int64), allocatable :: k2(:)
    integer(int32), allocatable :: c2(:)

    allocate(k2(2 * size(c%keys)), c2(2 * size(c%keys)))
    k2(1:c%n-1) = c%keys(1:c%n-1)
    c2(1:c%n-1) = c%counts(1:c%n-1)
    call move_alloc(k2, c%keys)
    call move_alloc(c2, c%counts)
  end subroutine grow

end module oligonucleotides

program knucleotide
  use iso_fortran_env, only: int8, int32, int64
  use iso_c_binding, only: c_size_t, c_long
  use posix_read
  use oligonucleotides
  implicit none

  integer, parameter :: CHUNK = 1048576
  integer(int8), parameter :: EOL = 10, GT = iachar('>', int8)
  character(len=*), parameter :: three = '>THREE'
  character(len=4), parameter :: letters = 'ACGT'

  integer(int8), allocatable :: input(:), seq(:), w(:)
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

  call write_frequencies(seq(1:nseq), 1)
  call write_frequencies(seq(1:nseq), 2)
  call write_count(seq(1:nseq), 'GGT')
  call write_count(seq(1:nseq), 'GGTA')
  call write_count(seq(1:nseq), 'GGTATT')
  call write_count(seq(1:nseq), 'GGTATTTTAATT')
  call write_count(seq(1:nseq), 'GGTATTTTAATTTATAGT')

contains

  ! Every oligonucleotide of length k with its percentage, most frequent
  ! first, then by code.
  subroutine write_frequencies(seq, k)
    integer(int8), intent(in) :: seq(:)
    integer, intent(in) :: k
    type(counter) :: c
    integer :: i, j, best, total
    integer(int64) :: tk, code
    integer(int32) :: tc
    character(len=k) :: name

    call count_all(seq, k, c)
    ! At most 16 entries: a selection sort by count, then by code.
    do i = 1, c%n - 1
       best = i
       do j = i + 1, c%n
          if (c%counts(j) > c%counts(best) .or. &
              (c%counts(j) == c%counts(best) .and. c%keys(j) < c%keys(best))) best = j
       end do
       tk = c%keys(i); c%keys(i) = c%keys(best); c%keys(best) = tk
       tc = c%counts(i); c%counts(i) = c%counts(best); c%counts(best) = tc
    end do
    total = size(seq) - k + 1
    do i = 1, c%n
       code = c%keys(i)
       do j = k, 1, -1
          name(j:j) = letters(iand(code, 3_int64) + 1:iand(code, 3_int64) + 1)
          code = shiftr(code, 2)
       end do
       ! The C program divides in single precision.
       write(*, '(a," ",f0.3)') name, 100.0 * real(c%counts(i)) / real(total)
    end do
    write(*, '(a)') ''
  end subroutine write_frequencies

  ! The number of times the oligonucleotide s occurs.
  subroutine write_count(seq, s)
    integer(int8), intent(in) :: seq(:)
    character(len=*), intent(in) :: s
    type(counter) :: c
    type(key_type) :: key
    class(*), allocatable :: other
    logical :: exists
    integer(int64) :: code
    integer :: i, count

    call count_all(seq, len(s), c)
    code = 0
    do i = 1, len(s)
       code = ior(shiftl(code, 2), int(code_of(iachar(s(i:i))), int64))
    end do
    call set(key, transfer(code, [0_int8], 8))
    call c%map%get_other_data(key, other, exists)
    count = 0
    if (exists) then
       select type (other)
       type is (integer)
          count = c%counts(other)
       end select
    end if
    write(*, '(i0,a,a)') count, achar(9), s
  end subroutine write_count

end program knucleotide
