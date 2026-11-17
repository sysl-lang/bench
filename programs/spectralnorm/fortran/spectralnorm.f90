! The Computer Language Benchmarks Game
! https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
!
! contributed by Steve Decker based on the version by Simon Geard
! compilation:
!   g95 -O1 -fomit-frame-pointer -funroll-loops spectral_norm.f90
!   ifort -ipo -O3 -static spectral_norm.f90
module norm_subs
  implicit none

  integer, parameter :: dp = selected_real_kind(12)

contains

  ! Return element i,j of infinite matrix A
  pure real(dp) function A(i, j)
    integer, intent(in) :: i, j

    a = 1.d0 / ((i+j-2) * (i+j-1)/2 + i)
  end function A

  ! Multiply v by A
  pure subroutine MultiplyAv(v, Av)
    real(dp), dimension(:), intent(in)  :: v
    real(dp), dimension(:), intent(out) :: Av

    integer :: n, i, j
    real(dp) :: s

    n = size(v)
    do i = 1, n
       s = 0.d0
       do j = 1, n
          s = s + A(i,j) * v(j)
       end do
       Av(i) = s
    end do
  end subroutine MultiplyAv

  ! Multiply v by A transpose
  pure subroutine MultiplyAtv(v, Atv)
    real(dp), dimension(:), intent(in)  :: v
    real(dp), dimension(:), intent(out) :: Atv

    integer :: n, i, j
    real(dp) :: s

    n = size(v)
    do i = 1, n
       s = 0.d0
       do j = 1, n
          s = s + A(j,i) * v(j)
       end do
       Atv(i) = s
    end do
  end subroutine MultiplyAtv

  ! Multiply v by A and then by A transpose
  pure subroutine MultiplyAtAv(v, tmp, AtAv)
    real(dp), dimension(:), intent(in)    :: v
    real(dp), dimension(:), intent(inout) :: tmp
    real(dp), dimension(:), intent(out)   :: AtAv

    call MultiplyAv(v, tmp)
    call MultiplyAtv(tmp, AtAv)
  end subroutine MultiplyAtAv
end module norm_subs

program spectral_norm
  use norm_subs
  implicit none

  real(dp), dimension(:), allocatable :: u, v, tmp
  integer          :: i, n
  character(len=12) :: argv

  call get_command_argument(1, argv)
  read(argv, *) n

  allocate(u(n), v(n), tmp(n))
  u = 1.d0
  do i = 1, 10
     call MultiplyAtAv(u, tmp, v)
     call MultiplyAtAv(v, tmp, u)
  end do

  write(*, "(f0.9)") sqrt(dot_product(u,v) / dot_product(v,v))
  deallocate(u, v, tmp)
end program spectral_norm
