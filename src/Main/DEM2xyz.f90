!-------------------------------------------------------------------------------
! "DEM2xyz v.1.0" (DEM manager tool)
! Copyright 2016 (RSE SpA)
! "DEM2xyz v.1.0" authors and email contact are provided on the documentation 
! file.
! This file is part of DEM2xyz v.1.0 .
! DEM2xyz v.1.0 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
! DEM2xyz is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
! You should have received a copy of the GNU General Public License
! along with DEM2xyz. If not, see <http://www.gnu.org/licenses/>.
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! Description. “DEM2xyz v.1.0” (RSE SpA) reads a “DEM” file and writes the 
!              associated DEM in a corresponding “xyz” file, possibly 
!              changing the spatial resolution (as requested by the user). 
!              In case the absolute value of the mean latitude is provided with
!              a non-negative value, the following conversion takes place 
!              "(lon,lat) in (°) to (X,Y) in (m)". In this case, an 
!              interpolation (weighted on the square of the distance) is 
!              carried out to provide a regular Cartesian output grid in (X,Y). 
!              The height of the DEM points which belong to the digging/filling 
!              regions (provided in input) is modified. After this treatment, 
!              each digging/filling region has null slope. 
!              Bathymetry is possibly extruded from the heights of the 
!              most upstream and downstream coastline points.
!              The bathymetry/reservoir extrusion is corrected in case the  
!              volume reservoir is provided as an input parameter.
!              Multiple reservoirs are admitted.
!              Digging regions cannot overlap each other.
!              Reservoir/bathymetry regions cannot overlap each other.
!              In case a digging region overlaps a reservoir region, the latter 
!              holds the priority.
!              In the presence of a volume correction, two reference shapes are 
!                 available: "reservoir" and "volcanic lake".
!              Variables:
!              input variables (ref. template of the main input file)
!              coastline(n_bathymetries,n_rows,n_col_out): logical flag to 
!                 detect the reservoir coastline.
!              dis_Pdown_Pint: distance between the most downstream point (m) 
!                 and the current intersection point
!              dis_down_up(n_bathymetries): distance between the most upstream 
!                 and downstream points (m)
!              dis_Pint_Pcoast: distance between "point_coast" and "Pint" 
!              dx,dy: spatial resolution -final values in (m)-
!              mat_z_in(n_row_n_col_in): input DEM
!              mat_z_out(n_row_n_col_out): output DEM
!              n_col_in: number of columns in the input DEM
!              n_col_out: number of columns in the output DEM
!              n_points_in: number of input vertices
!              n_points_out: number of output vertices
!              n_row: number of rows in the input/output DEM
!              Pint(2): intersection between the line r_down_up (passing for  
!                 both the upstream and the downstream points) and the line r_iC 
!                 (passing for the current reservoir "point" and the associated 
!                 coastline point).
!              point_coast(2): provided an inner reservoir point, to detect the 
!                 associated coast point which belongs to the same coast side 
!                 and is the closest to the line r_iC. This line passes for the 
!                 inner reservoir point and is parallel to the above normal.
!              reservoir(n_bathymetries,n_rows,n_col_out): logical flag to 
!                 detect the reservoir.
!              volume_res_est(n_bathymetries): first estimations of the 
!                 reservoir volumes
!              volume_res_corr(n_bathymetries): corrected estimations of the 
!                 reservoir volumes
!              weight(n_bathymetries,n_row,n_col_out): point weights for 
!                 reservoir volume corrections
!              weight_sum(n_bathymetries): weight sums 
!              x_in,y_in: horizontal coordinates in input -(m) or (°)- 
!              x_out,y_out: horizontal coordinates in output (m)
!              z_Pint: hieght of the point Pint (m)
!-------------------------------------------------------------------------------
PROGRAM DEM2xyz
!------------------------
! Modules
!------------------------
!------------------------
! Declarations
!------------------------
implicit none
logical :: test_logical
integer :: i_in,j_in,i_out,j_out,n_col_in,n_col_out,n_row,res_fact,n_points_in
integer :: n_points_out,i_aux,j_aux,n_digging_regions,i_reg,test_integer
integer :: i_bath,aux_integer,i_close,j_close,j2_out,i2_out,n_bathymetries
double precision :: dx,dy,abs_mean_latitude,denom,distance,x_in,x_out,y_in,y_out
double precision :: dis,dis2,min_dis2,z_Pint,dis_Pint_Pcoast,aux_scalar
double precision :: dis_Pdown_Pint,aux_scalar_2,aux_scalar_3
double precision :: dis3
double precision :: point(2),point2(2),point_plus_normal(2),normal(2),normal2(2)
double precision :: point_coast(2),Pint(2)
logical,dimension(:),allocatable :: volume_flag
integer,dimension(:),allocatable :: n_digging_vertices,n_vertices_around_res
integer,dimension(:),allocatable :: weight_type(:)
double precision,dimension(:),allocatable :: z_digging_regions,z_FS,z_eps
double precision,dimension(:),allocatable :: z_downstream,volume_res_est
double precision,dimension(:),allocatable :: volume_res_inp,weight_sum
double precision,dimension(:),allocatable :: dis_down_up,volume_res_corr
double precision,dimension(:,:),allocatable :: mat_z_in,mat_z_out
double precision,dimension(:,:),allocatable :: pos_res_downstream
double precision,dimension(:,:),allocatable :: pos_res_upstream
logical,dimension(:,:,:),allocatable :: reservoir,coastline
double precision,dimension(:,:,:),allocatable :: digging_vertices,weight
double precision,dimension(:,:,:),allocatable :: vertices_around_res
character(len=100) :: char_aux
!------------------------
! Explicit interfaces
!------------------------
interface
   subroutine point_inout_convex_non_degenerate_polygon(point,n_sides,         &
                                                        point_pol_1,           &
                                                        point_pol_2,           &
                                                        point_pol_3,           &
                                                        point_pol_4,           &
                                                        point_pol_5,           &
                                                        point_pol_6,test)
      implicit none
      integer(4),intent(in) :: n_sides
      double precision,intent(in) :: point(2),point_pol_1(2),point_pol_2(2)
      double precision,intent(in) :: point_pol_3(2),point_pol_4(2)
      double precision,intent(in) :: point_pol_5(2),point_pol_6(2)
      integer(4),intent(inout) :: test
   end subroutine point_inout_convex_non_degenerate_polygon
end interface
interface
   subroutine point_inout_hexagon(point,point_pol_1,point_pol_2,point_pol_3,   &
                                  point_pol_4,point_pol_5,point_pol_6,test)
      implicit none
      double precision,intent(in) :: point(2),point_pol_1(2),point_pol_2(2)
      double precision,intent(in) :: point_pol_3(2),point_pol_4(2)
      double precision,intent(in) :: point_pol_5(2),point_pol_6(2)
      integer(4),intent(inout) :: test
   end subroutine point_inout_hexagon
end interface
interface
   subroutine point_inout_pentagon(point,point_pol_1,point_pol_2,point_pol_3,  &
                                   point_pol_4,point_pol_5,test)
      implicit none
      double precision,intent(in) :: point(2),point_pol_1(2),point_pol_2(2)
      double precision,intent(in) :: point_pol_3(2),point_pol_4(2)
      double precision,intent(in) :: point_pol_5(2)
      integer(4),intent(inout) :: test
   end subroutine point_inout_pentagon
end interface
interface
   subroutine point_inout_quadrilateral(point,point_pol_1,point_pol_2,         &
                                        point_pol_3,point_pol_4,test)
      implicit none
      double precision,intent(in) :: point(2),point_pol_1(2),point_pol_2(2)
      double precision,intent(in) :: point_pol_3(2),point_pol_4(2)
      integer(4),intent(inout) :: test
   end subroutine point_inout_quadrilateral
end interface
interface
   subroutine distance_point_line_2D(P0,P1_line,P2_line,dis,normal)
      implicit none
      double precision,intent(in) :: P0(2),P1_line(2),P2_line(2)
      double precision,intent(inout) :: dis
      double precision,intent(inout) :: normal(2)
   end subroutine distance_point_line_2D
end interface
interface
   subroutine line_line_intersection_2D(P1_line1,P2_line1,P1_line2,P2_line2,   &
                                        Pint,test)
      implicit none
      double precision,intent(in) :: P1_line1(2),P2_line1(2),P1_line2(2)
      double precision,intent(in) :: P2_line2(2)
      logical,intent(out) :: test
      double precision,intent(out) :: Pint(2)
   end subroutine line_line_intersection_2D
end interface
!------------------------
! Allocations
!------------------------
!------------------------
! Initializations
!------------------------
n_digging_regions = 0
n_bathymetries = 0
!------------------------
! Statements
!------------------------
write(*,*) "DEM2xyz v.1.0 (RSE SpA) is running. DEM2xyz is a DEM manager tool. "
write(*,*) "Reading DEM file, DEM2xyz main input file and pre-processing. "
open(11,file='DEM.dem')
read(11,'(a14,i15)') char_aux,n_col_in
read(11,'(a14,i15)') char_aux,n_row
read(11,'(a)')
read(11,'(a)')
read(11,'(a14,f15.7)') char_aux,dy
allocate(mat_z_in(n_row,n_col_in))
mat_z_in = 0.d0
read(11,'(a)')
do i_in=1,n_row
   read(11,*) mat_z_in(i_in,:)
enddo
close(11)
open(12,file='DEM2xyz.inp')
read(12,*) res_fact,abs_mean_latitude,n_digging_regions,n_bathymetries
if (n_digging_regions>0) then
   allocate(n_digging_vertices(n_digging_regions))
   allocate(z_digging_regions(n_digging_regions))
   allocate(digging_vertices(n_digging_regions,6,2))
   n_digging_vertices(:) = 0
   z_digging_regions(:) = 0.d0
   digging_vertices(:,:,:) = 0.d0
   do i_reg=1,n_digging_regions
      read(12,*) z_digging_regions(i_reg),n_digging_vertices(i_reg)
      do j_aux=1,n_digging_vertices(i_reg)
         read (12,*) digging_vertices(i_reg,j_aux,1:2)
      enddo
   enddo
endif
if (n_bathymetries>0) then
   allocate(volume_flag(n_bathymetries))
   allocate(n_vertices_around_res(n_bathymetries))
   allocate(z_downstream(n_bathymetries))
   allocate(z_FS(n_bathymetries))
   allocate(z_eps(n_bathymetries))
   allocate(volume_res_est(n_bathymetries))
   allocate(volume_res_inp(n_bathymetries))
   allocate(volume_res_corr(n_bathymetries))
   allocate(weight_sum(n_bathymetries))
   allocate(dis_down_up(n_bathymetries))
   allocate(weight_type(n_bathymetries))
   allocate(pos_res_downstream(n_bathymetries,2))
   allocate(pos_res_upstream(n_bathymetries,2))
   allocate(vertices_around_res(n_bathymetries,6,2))
   volume_flag(:) = .false.
   n_vertices_around_res(:) = 0
   z_downstream(:) = 0.d0
   z_FS(:) = 0.d0
   z_eps(:) = 0.d0
   volume_res_est(:) = 0.d0
   volume_res_inp(:) = 0.d0
   volume_res_corr(:) = 0.d0
   weight_sum(:) = 0.d0
   dis_down_up(:) = 0.d0
   weight_type(:) = 0
   pos_res_downstream(:,:) = 0.d0
   pos_res_upstream(:,:) = 0.d0
   vertices_around_res(:,:,:) = 0.d0
   do i_bath=1,n_bathymetries
      read(12,*) pos_res_downstream(i_bath,1),pos_res_downstream(i_bath,2),    &
         z_downstream(i_bath),pos_res_upstream(i_bath,1),                      &
         pos_res_upstream(i_bath,2),z_FS(i_bath),z_eps(i_bath),                &
         volume_flag(i_bath),weight_type(i_bath),n_vertices_around_res(i_bath)
      do j_aux=1,n_vertices_around_res(i_bath)
         read(12,*) vertices_around_res(i_bath,j_aux,1),                       &
            vertices_around_res(i_bath,j_aux,2)
      enddo
      if (volume_flag(i_bath).eqv..true.) then
         read(12,*) volume_res_inp(i_bath) 
      endif
! Distance between the most upstream and downstream points
      dis_down_up(i_bath) = dsqrt((pos_res_upstream(i_bath,1) -                &
                 pos_res_downstream(i_bath,1)) ** 2 +                          &
                 (pos_res_upstream(i_bath,2) - pos_res_downstream(i_bath,2))   &
                 ** 2)
   enddo
endif
close(12)
if (abs_mean_latitude>=0.d0) then
! Conversion degrees to radians 
abs_mean_latitude = abs_mean_latitude / 180.d0 * 3.1415926
! Conversion (lon,lat) in (°) to (X,Y) in (m) for dx and dy
! Linear unit discretization along the same parallel/latitude due to changing 
! in longitude according to the DEM input discretization
   dx = dy * (111412.84d0 * dcos(abs_mean_latitude) - 93.5d0 * dcos(3.d0 *     &
        abs_mean_latitude) + 0.118d0 * dcos(5.d0 * abs_mean_latitude))
! Linear unit discretization along the same meridian/longitude due to changing 
! in latitude according to the DEM input discretization
   dy = dy * (111132.92d0 - 559.82d0 * dcos(2.d0 * abs_mean_latitude) +        &
        1.175d0 * dcos(4.d0 * abs_mean_latitude) - 0.0023d0 * dcos(6.d0 *      &
        abs_mean_latitude))
   n_col_out = floor(n_col_in * dx / dy)
   else
      dx = dy
      n_col_out = n_col_in
endif
allocate(mat_z_out(n_row,n_col_out))
mat_z_out = 0.d0
if (n_bathymetries>0) then
   allocate(reservoir(n_bathymetries,n_row,n_col_out))
   reservoir(:,:,:) = .false.
   allocate(coastline(n_bathymetries,n_row,n_col_out))
   coastline(:,:,:) = .false.
   allocate(weight(n_bathymetries,n_row,n_col_out))
   weight(:,:,:) = 0.d0
endif
write(*,*) "Eventual grid interpolation, eventual digging/filling DEM ",       &
   "regions, eventual reservoir detection and writing xyz file (version ",     &
   "before the eventual reservoir/batymetry extrusions). "
open(13,file="xyz_no_extrusion.txt")
write(13,'(a)') '        x(m)       y(m)        z(m)        z   '
n_points_in = n_row * n_col_in / res_fact / res_fact
n_points_out = n_row * n_col_out / res_fact / res_fact
write(*,'(a,i15)') 'Number of vertices in the input "DEM" file: ',n_points_in
write(*,'(a,i15)') 'Number of vertices in the output "xyz" file: ',n_points_out
do j_out=1,n_col_out,res_fact
   do i_out=1,n_row,res_fact
      x_out = (j_out - 1) * dy + dy / 2.d0
      y_out = (n_row + 1 - i_out) * dy - dy / 2.d0
      if (abs_mean_latitude>=0.d0) then      
! Interpolation: inverse of the distance**2
         denom = 0.d0
         j_aux = nint((j_out - 0.5) * real(dy / dx) + 0.5)
         i_aux = i_out
         do j_in=(j_aux-1),(j_aux+1)
            do i_in=(i_aux-1),(i_aux+1)
               if ((i_in<1).or.(i_in>n_row).or.(j_in<1).or.(j_in>n_col_in))    &
                  cycle
               x_in = (j_in - 1) * dx + dx / 2.d0
               y_in = (n_row + 1 - i_in) * dy - dy / 2.d0
               distance = dsqrt((x_in - x_out) ** 2 + (y_in - y_out) ** 2)
               if (distance<=dy) then
                  mat_z_out(i_out,j_out) = mat_z_out(i_out,j_out) +            &
                                           mat_z_in(i_in,j_in) / distance ** 2
                  denom = denom + 1.d0 / distance ** 2
               endif
            enddo
         enddo
         if (denom/=0.d0) mat_z_out(i_out,j_out) = mat_z_out(i_out,j_out) /    &
                                                   denom
         else
! No interpolation (dx=dy)
            mat_z_out(i_out,j_out) = mat_z_in(i_out,j_out)
      endif

! Reservoir detection
      do i_bath=1,n_bathymetries
         test_integer = 0
         point(1) = x_out
         point(2) = y_out
         select case(n_vertices_around_res(i_bath))
            case(3)
               call point_inout_convex_non_degenerate_polygon(point,3,         &
                  vertices_around_res(i_bath,1,1:2),                           &
                  vertices_around_res(i_bath,2,1:2),                           &
                  vertices_around_res(i_bath,3,1:2),point,point,point,         &
                  test_integer)
            case(4)
               call point_inout_quadrilateral(point,                           &
                  vertices_around_res(i_bath,1,1:2),                           &
                  vertices_around_res(i_bath,2,1:2),                           &
                  vertices_around_res(i_bath,3,1:2),                           &
                  vertices_around_res(i_bath,4,1:2),test_integer)
            case(5)
               call point_inout_pentagon(point,                                &
                  vertices_around_res(i_bath,1,1:2),                           &
                  vertices_around_res(i_bath,2,1:2),                           &
                  vertices_around_res(i_bath,3,1:2),                           &
                  vertices_around_res(i_bath,4,1:2),                           &
                  vertices_around_res(i_bath,5,1:2),test_integer)
            case(6)
               call point_inout_hexagon(point,                                 &
                  vertices_around_res(i_bath,1,1:2),                           &
                  vertices_around_res(i_bath,2,1:2),                           &
                  vertices_around_res(i_bath,3,1:2),                           &
                  vertices_around_res(i_bath,4,1:2),                           &
                  vertices_around_res(i_bath,5,1:2),                           &
                  vertices_around_res(i_bath,6,1:2),test_integer)
         endselect
         if (test_integer>0) then
            if ((mat_z_out(i_out,j_out)<=(z_FS(i_bath)+z_eps(i_bath))).and.    &
               (mat_z_out(i_out,j_out)>=(z_FS(i_bath)-z_eps(i_bath)))) then
               reservoir(i_bath,i_out,j_out) = .true.
            endif
         endif
      enddo
! Detection of the digging/filling regions      
      do i_reg=1,n_digging_regions
         test_integer = 0
         point(1) = x_out
         point(2) = y_out
         select case(n_digging_vertices(i_reg))
            case(3)
               call point_inout_convex_non_degenerate_polygon(point,3,         &
                  digging_vertices(i_reg,1,1:2),digging_vertices(i_reg,2,1:2), &
                  digging_vertices(i_reg,3,1:2),point,point,point,test_integer)
            case(4)
               call point_inout_quadrilateral(point,                           &
                  digging_vertices(i_reg,1,1:2),digging_vertices(i_reg,2,1:2), &
                  digging_vertices(i_reg,3,1:2),digging_vertices(i_reg,4,1:2), &
                  test_integer)
            case(5)
               call point_inout_pentagon(point,                                &
                  digging_vertices(i_reg,1,1:2),digging_vertices(i_reg,2,1:2), &
                  digging_vertices(i_reg,3,1:2),digging_vertices(i_reg,4,1:2), &
                  digging_vertices(i_reg,5,1:2),test_integer)
            case(6)
               call point_inout_hexagon(point,digging_vertices(i_reg,1,1:2),   &
                  digging_vertices(i_reg,2,1:2),digging_vertices(i_reg,3,1:2), &
                  digging_vertices(i_reg,4,1:2),digging_vertices(i_reg,5,1:2), &
                  digging_vertices(i_reg,6,1:2),test_integer)
         endselect
         if (test_integer>0) then
            mat_z_out(i_out,j_out) = z_digging_regions(i_reg)
         endif
      enddo
      write(13,'(4(F12.4))') x_out,y_out,mat_z_out(i_out,j_out),               &
         mat_z_out(i_out,j_out)
   enddo
enddo
close(13)
if (n_bathymetries>0) then
   write(*,*) "Coastline detections. "   
! Coastline detections
   do j_out=1,n_col_out,res_fact
      do i_out=1,n_row,res_fact
         do i_bath=1,n_bathymetries
            if (reservoir(i_bath,i_out,j_out).eqv..true.) then
               aux_integer = 0
               close_points: do j_close=j_out-1,j_out+1
                  do i_close=i_out-1,i_out+1
                     if ((i_close<1).or.(i_close>n_row).or.(j_close<1).or.     &
                        (j_close>n_col_out)) exit close_points
                     if (reservoir(i_bath,i_close,j_close).eqv..true.) then
                        aux_integer = aux_integer + 1
                        else
                           exit close_points
                     endif
                  enddo
               enddo close_points
               if (aux_integer<8) then
                  coastline(i_bath,i_out,j_out) = .true.
               endif
            endif
         enddo
      enddo
   enddo
! Bathymetry extrusions
   write(*,*) "Bathymetry extrusions. "
! Loop over the DEM output points
   do j_out=1,n_col_out,res_fact
      do i_out=1,n_row,res_fact
         do_extrusion: do i_bath=1,n_bathymetries
            if (reservoir(i_bath,i_out,j_out).eqv..true.) then
! To treat inner reservoir points
               if (coastline(i_bath,i_out,j_out).eqv..true.) then
                  exit do_extrusion
               endif
! Position of current the inner reservoir point 
               point(1) = (j_out - 1) * dy + dy / 2.d0
               point(2) = (n_row + 1 - i_out) * dy - dy / 2.d0
! Distance (project on the horizontal) between a reservoir point and the line 
! passing for the upstream and the downstream points. 
! Unit vector perpendicular to the line. 
               call distance_point_line_2D(point,                              &
                  pos_res_downstream(i_bath,1:2),pos_res_upstream(i_bath,1:2), &
                  dis,normal)
! Position of a second point belonging to the line r_iC (beyond the centreline 
! "point")
               point_plus_normal(1) = point(1) + 1000.d0 * normal(1)
               point_plus_normal(2) = point(2) + 1000.d0 * normal(2)
! point_coast
               point_coast(:) = -9.d8
               min_dis2 = 9.d8
! Loop over the DEM output points
               do j2_out=1,n_col_out,res_fact
                  do i2_out=1,n_row,res_fact
                     if (coastline(i_bath,i2_out,j2_out).eqv..true.) then
! To treat the coast points
! Position of the generic coast point
                        point2(1) = (j2_out - 1) * dy + dy / 2.d0
                        point2(2) = (n_row + 1 - i2_out) * dy - dy / 2.d0
! Distance between the coast point and the line r_iC
                        call distance_point_line_2D(point2,point,              &
                           point_plus_normal,dis2,normal2)
! Distance (project on the horizontal) between the coastline point and the line 
! passing for the upstream and the downstream points. 
                        call distance_point_line_2D(point2,                    &
                           pos_res_downstream(i_bath,1:2),                     &
                           pos_res_upstream(i_bath,1:2),dis3,normal2)                        
! To update the position of the associated coast point
                        aux_scalar = dabs(dis2)
                        if ((aux_scalar<min_dis2).and.((dis*dis3)>=0.d0)) then
                           min_dis2 = aux_scalar
                           point_coast(:) = point2(:)
                        endif
                     endif
                  enddo
               enddo
               if (point_coast(1)<-8.9d8) then
                  write(*,*) 'The following inner reservoir point cannot be ', &
                     'associated to any coast point: ',point(1:2),'The ',      &
                     'program stops here. '
                  stop
               endif
! Pint
               call line_line_intersection_2D(pos_res_downstream(i_bath,1:2),  &
                  pos_res_upstream(i_bath,1:2),point,point_coast,Pint,         &
                  test_logical)
               if (test_logical.eqv..false.) then
                  write(*,*) 'Error. The intersection between the present ',   &
                     'two lines does not provide an unique point. The ',       &
                     'program stops here. '
                  write(*,*) 'pos_res_downstream(i_bath,1:2): ',               &
                     pos_res_downstream(i_bath,1:2)
                  write(*,*) 'pos_res_upstream(i_bath,1:2): ',                 &
                     pos_res_upstream(i_bath,1:2)
                  write(*,*) 'point(1:2): ',point(:)
                  write(*,*) 'point_coast(1:2): ',point_coast(:)
                  stop
               endif
! Bathymetry height at the intersection point Pint (linear interpolation)
               dis_Pdown_Pint = dsqrt((pos_res_downstream(i_bath,1) - Pint(1)) &
                                ** 2 + (pos_res_downstream(i_bath,2) -         &
                                Pint(2)) ** 2)
               z_Pint = z_downstream(i_bath) + dabs(dis_Pdown_Pint /           &
                        dis_down_up(i_bath)) * (z_FS(i_bath) -                 &
                        z_downstream(i_bath))
! Distance (projected along the horizontal) between the coast point and the 
! line r_down_up (or the point Pint)
               dis_Pint_Pcoast = dsqrt((point_coast(1) - Pint(1)) ** 2 +       &
                                 (point_coast(2) - Pint(2)) ** 2)
! Bathymetry height at the inner reservoir point (linear interpolation)
               mat_z_out(i_out,j_out) = z_Pint + min(dabs(dis /                &
                                        dis_Pint_Pcoast),1.d0) * (z_FS(i_bath) &
                                        - z_Pint)
! To update the estimated reservoir volume
               volume_res_est(i_bath) = volume_res_est(i_bath) + (z_FS(i_bath) &
                                        - mat_z_out(i_out,j_out)) * (dy ** 2)
               if (volume_flag(i_bath).eqv..true.) then
! Volume correction is active
! To compute the weight for the volume correction
                  if (weight_type(i_bath)==1) then
                     weight(i_bath,i_out,j_out) = max((mat_z_out(i_out,j_out)  &
                                                  - z_downstream(i_bath)),0.d0)
                     elseif (weight_type(i_bath)==2) then
                        aux_scalar_3 = dabs(dis_Pdown_Pint /                   &
                                       dis_down_up(i_bath))
                        if (aux_scalar_3<=0.5d0) then
                           aux_scalar = 0.d0
                           aux_scalar_2 = 1.d0
                           else
                              aux_scalar = 1.d0
                              aux_scalar_2 = -1.d0
                        endif
                        weight(i_bath,i_out,j_out) = 2.d0 * (aux_scalar +      &
                                                     aux_scalar_2 *            &
                                                     aux_scalar_3) * (1.d0 -   &
                                                     min(dabs(dis /            &
                                                     dis_Pint_Pcoast),1.d0))
                        write(*,*) "weight(i_bath,i_out,j_out): ",             &
                           weight(i_bath,i_out,j_out)
                        write(*,*) "aux_scalar: ",aux_scalar
                        write(*,*) "aux_scalar_2",aux_scalar_2
                        write(*,*) "aux_scalar_3",aux_scalar_3
                        write(*,*) "dis",dis
                        write(*,*) "dis_Pint_Pcoast",dis_Pint_Pcoast
                        else
                           write(*,*) "A reservoir volume correction is ",     &
                              "requested, but no admissible weight type is ",  &
                              "selected. The program stops here. "
                           stop 
                  endif
! To update the weight sum
                  weight_sum(i_bath) = weight_sum(i_bath) +                    &
                                       weight(i_bath,i_out,j_out)
               endif
            endif
         enddo do_extrusion
      enddo
   enddo
! Bathymetry correction on the actual reservoir volumes (for inner reservoir 
! points)
   write(*,*) "Possible bathymetry corrections on the actual reservoir volumes."
   do i_bath=1,n_bathymetries
      write(*,*) "Reservoir ",i_bath,": first volume estimation is ",          &
         volume_res_est(i_bath),"m**3 . "
      if (volume_flag(i_bath).eqv..true.) then
! Volume correction is active
         write(*,*) "Reservoir ",i_bath,": input/corrected volume is ",        &
            volume_res_inp(i_bath),"m**3 . "
         else
            write(*,*) "Reservoir ",i_bath,": no input/corrected volume is ",  &
            "provided . "
      endif
   enddo
   do j_out=1,n_col_out,res_fact
      do i_out=1,n_row,res_fact
         do_correction: do i_bath=1,n_bathymetries
            if (volume_flag(i_bath).eqv..true.) then
! Volume correction is active
! Bathymetry correction is applied in case a reservoir volume is provided in 
! input
               if (reservoir(i_bath,i_out,j_out).eqv..true.) then
! To treat inner reservoir points
                  if (coastline(i_bath,i_out,j_out).eqv..true.) then
                     exit do_correction
                  endif
                  mat_z_out(i_out,j_out) = mat_z_out(i_out,j_out) +            &
                                           (volume_res_est(i_bath) -           &
                                           volume_res_inp(i_bath)) *           &
                                           (weight(i_bath,i_out,j_out) /       &
                                           weight_sum(i_bath)) / (dy ** 2)
! To update the corrected reservoir volume
                  volume_res_corr(i_bath) = volume_res_corr(i_bath) +          &
                                           (z_FS(i_bath) -                     &
                                           mat_z_out(i_out,j_out)) * (dy ** 2)
               endif
            endif
         enddo do_correction
      enddo
   enddo
! Possible writing of the corrected reservoir volumes
   do i_bath=1,n_bathymetries
      if (volume_flag(i_bath).eqv..true.) then
! Volume correction is active
         write(*,*) "Reservoir ",i_bath,": corrected volume estimation is ",   &
            volume_res_corr(i_bath),"m**3 . "
      endif
   enddo
   write(*,*) "Eventual writing of the xyz file (version after the ",          &
      "reservoir/batymetry extrusions). "
   open(14,file="xyz_with_extrusions.txt")
   write(14,'(a)') '        x(m)       y(m)        z(m)        z   '
   do j_out=1,n_col_out,res_fact
      do i_out=1,n_row,res_fact
         x_out = (j_out - 1) * dy + dy / 2.d0
         y_out = (n_row + 1 - i_out) * dy - dy / 2.d0
         write(14,'(4(F12.4))') x_out,y_out,mat_z_out(i_out,j_out),            &
            mat_z_out(i_out,j_out)
      enddo
   enddo
   close(14)
   open(15,file="weight_bathymetry_1.txt")
   write(15,'(a)') '        x(m)       y(m)        z(m)        z   '
   do j_out=1,n_col_out,res_fact
      do i_out=1,n_row,res_fact
         x_out = (j_out - 1) * dy + dy / 2.d0
         y_out = (n_row + 1 - i_out) * dy - dy / 2.d0
         write(15,'(4(F12.4))') x_out,y_out,weight(1,i_out,j_out),             &
            weight(1,i_out,j_out)
      enddo
   enddo
   close(15)
endif
!------------------------
! Deallocations
!------------------------
deallocate(mat_z_in)
deallocate(mat_z_out)
if (n_digging_regions>0) then
   deallocate(n_digging_vertices)
   deallocate(z_digging_regions)
   deallocate(digging_vertices)
endif
if (n_bathymetries>0) then
   deallocate(n_vertices_around_res)
   deallocate(z_downstream)
   deallocate(z_FS)
   deallocate(z_eps)
   deallocate(volume_res_est)
   deallocate(volume_res_inp)
   deallocate(volume_res_corr)
   deallocate(weight_sum)
   deallocate(dis_down_up)
   deallocate(pos_res_downstream)
   deallocate(pos_res_upstream)
   deallocate(vertices_around_res)
   deallocate(reservoir)
   deallocate(coastline)
   deallocate(volume_flag)
   deallocate(weight)
   deallocate(weight_type)
endif
write(*,*) "DEM2xyz has terminated. "
end program DEM2xyz
