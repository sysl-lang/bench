! The Computer Language Benchmarks Game
! https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
!
! fasta implementation - translated from the lua program
! contributed by Simon Geard, 18/1/05
! modified by Andrei Jirnyi

program fasta
  implicit none

  integer, parameter :: dp = kind(1.d0)
  integer, parameter :: IM = 139968, IA = 3877, IC = 29573
  integer, parameter :: LW = 60, BUFSIZE = 65536
  character(len=*), parameter :: alu = &
'GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG' // &
'GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA' // &
'CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT' // &
'ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA' // &
'GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG' // &
'AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC' // &
'AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA'
  character(len=1), parameter :: EOL = achar(10)

  real(dp), parameter :: iub_p(15) = [0.27_dp, 0.12_dp, 0.12_dp, 0.27_dp, &
       [0.02_dp, 0.02_dp, 0.02_dp, 0.02_dp, 0.02_dp, 0.02_dp, 0.02_dp, 0.02_dp, &
        0.02_dp, 0.02_dp, 0.02_dp]]
  real(dp), parameter :: homosapiens_p(4) = [0.3029549426680_dp, 0.1979883004921_dp, &
       0.1975473066391_dp, 0.3015094502008_dp]

  integer :: num, out, nbuf = 0, last = 42
  character(len=12) :: argv
  character(len=1) :: obuf(BUFSIZE)

  call get_command_argument(1, argv)
  read(argv, *) num

  open(newunit=out, file='/dev/stdout', access='stream', form='unformatted', action='write')

  call put('>ONE Homo sapiens alu' // EOL)
  call makeRepeatFasta(alu, num*2)

  call put('>TWO IUB ambiguity codes' // EOL)
  call makeRandomFasta('acgtBDHKMNRSVWY', iub_p, num*3)

  call put('>THREE Homo sapiens frequency' // EOL)
  call makeRandomFasta('acgt', homosapiens_p, num*5)

  if (nbuf > 0) write(out) obuf(1:nbuf)
  close(out)

contains

  ! Appends s to the output buffer, writing the buffer out when it is full.
  subroutine put(s)
    character(len=*), intent(in) :: s
    integer :: i

    if (nbuf + len(s) > BUFSIZE) then
       write(out) obuf(1:nbuf)
       nbuf = 0
    end if
    do i = 1, len(s)
       obuf(nbuf + i) = s(i:i)
    end do
    nbuf = nbuf + len(s)
  end subroutine put

  subroutine makeRandomFasta(chars, probs, n)
     character(len=*), intent(in) :: chars
     real(dp), intent(in) :: probs(:)
     integer, intent(in) :: n
     real(dp) :: p(size(probs)), v
     character(len=LW+1) :: line
     integer :: i, j, k, m, nsym, todo

     ! Cumulative probabilities, summed as the C program sums them.
     nsym = size(probs)
     p(1) = probs(1)
     do i = 2, nsym
        p(i) = probs(i) + p(i-1)
     end do

     todo = n
     do while (todo > 0)
        m = min(LW, todo)
        do j = 1, m
           last = mod(last * IA + IC, IM)
           v = 1.0_dp * last / IM
           ! Count the cumulative probabilities below v: the C program's
           ! linear lookup, which scans the whole table without branching.
           k = 1
           do i = 1, nsym - 1
              if (v > p(i)) k = k + 1
           end do
           line(j:j) = chars(k:k)
        end do
        line(m+1:m+1) = EOL
        call put(line(1:m+1))
        todo = todo - m
     end do
  end subroutine makeRandomFasta

  subroutine makeRepeatFasta(s, n)
     character(len=*), intent(in) :: s
     integer, intent(in) :: n
     character(len=len(s)+LW) :: ss
     character(len=LW+1) :: line
     integer :: k, m, todo

     ! The sequence followed by its own first line, so every output line
     ! is one contiguous slice, as in the C program.
     ss = s // s(1:LW)
     k = 1
     todo = n
     do while (todo > 0)
        m = min(LW, todo)
        line(1:m) = ss(k:k+m-1)
        line(m+1:m+1) = EOL
        call put(line(1:m+1))
        k = k + m
        if (k > len(s)) k = k - len(s)
        todo = todo - m
     end do
  end subroutine makeRepeatFasta

end program fasta
