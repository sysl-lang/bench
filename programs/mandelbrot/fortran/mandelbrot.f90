! The Computer Language Benchmarks Game
! https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
!
! contributed by Pascal Parois

program mandelbrot
  implicit none

  integer, parameter :: iter = 50
  integer, parameter :: dp = selected_real_kind(15, 307)
  real(dp), parameter :: limit2 = 4.0_dp

  real(dp), dimension(8) :: cr, zr, zi, tr, ti
  real(dp) :: ci
  integer :: w, nbytes, y, xb, x0, k, n, byte, pos, out
  character(len=1), dimension(:), allocatable :: buf
  character(len=16) :: argv
  character(len=32) :: header

  call get_command_argument(1, argv)
  read(argv, *) w
  nbytes = (w + 7) / 8

  allocate(buf(nbytes * w))
  pos = 0

  do y = 0, w - 1
     ci = 2.0_dp * real(y, dp) / w - 1.0_dp
     do xb = 0, nbytes - 1
        x0 = xb * 8
        do k = 1, 8
           cr(k) = 2.0_dp * real(x0 + k - 1, dp) / w - 1.5_dp
        end do

        zr = 0.0_dp
        zi = 0.0_dp
        tr = 0.0_dp
        ti = 0.0_dp

        ! Eight pixels at once. A pixel that has escaped keeps iterating (its
        ! magnitude only grows, to infinity and then NaN), and every test
        ! below is false for it, so it ends outside exactly as when it stops.
        do n = 1, iter
           zi = 2.0_dp * zr * zi + ci
           zr = tr - ti + cr
           tr = zr * zr
           ti = zi * zi
           if (.not. any(tr + ti <= limit2)) exit
        end do

        byte = 0
        do k = 1, 8
           if (tr(k) + ti(k) <= limit2 .and. x0 + k - 1 < w) byte = ibset(byte, 8 - k)
        end do
        pos = pos + 1
        buf(pos) = achar(byte)
     end do
  end do

  write(header, '("P4",a,i0," ",i0,a)') achar(10), w, w, achar(10)
  open(newunit=out, file='/dev/stdout', access='stream', form='unformatted', action='write')
  write(out) trim(header), buf
  close(out)
end program mandelbrot
