spool C:\Users\dmuha\Desktop\IS480(Fall2018)\Project\setup.txt

set echo on;
set serveroutput on;

--create package header for enrollment
create or replace package Enroll is
function valid_snum(
	p_snum students.snum%type)
	return varchar2;

function valid_callnum(
	p_callnum schclasses.callnum%type)
	return varchar2;
	
procedure repeat_enrollment(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
	
procedure double_enrollment(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
		
procedure credit_cap(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
	
procedure standing(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
	
procedure student_disqualified(
	p_snum students.snum%type,
	p_answer OUT varchar2);
	
procedure course_cap(
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
	
procedure proc_waitlist(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);

procedure AddMe(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
	
procedure check_enroll(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
	
procedure check_grade(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
	
procedure gradeW(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2);
	
procedure waitlistAdd(
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2); 
	
procedure DropMe(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type);
	
end Enroll;
/
	
--enroll package body
create or replace package body Enroll is

--create valid snum and callnum
function valid_snum(
	p_snum students.snum%type)
	return varchar2 as
	
	v_count number;
	v_error varchar2(1000);
begin
	select count(*) into v_count
	from students
	where snum = p_snum;
	
	if v_count = 1 then
		v_error := null;
	else
		v_error := 'Input Invalid Snum';
	end if;
	return v_error;
end;


function valid_callnum(
	p_callnum schclasses.callnum%type)
	return varchar2 as
	
	v_count number;
	v_error varchar2(1000);
begin
	select count(*) into v_count
	from schclasses
	where callnum = p_callnum;
	
	if v_count = 1 then
		v_error := null;
	else
		v_error := 'Invalid Callnum';
	end if;
	return v_error;
end;


--repeat enroll
procedure repeat_enrollment(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_count number;
	
begin
	select count(*) into v_count
	from enrollments
	where snum = p_snum and callnum = p_callnum;
	
	if v_count = 1 then
		p_answer := 'Student already enrolled in this class, cannot repeat enroll';
	else
		p_answer := null;
	end if;
end;

	
--double enrollment 
procedure double_enrollment(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as

	v_dept schclasses.dept%type;
	v_cnum schclasses.cnum%type;
		
	cursor CDoubleEnroll is
	select snum
	from schclasses sc , enrollments e
	where snum = p_snum and dept = v_dept
	and cnum = v_cnum and e.callnum = sc.callnum;
	
begin
	select dept into v_dept
	from schclasses
	where callnum = p_callnum;

	select cnum into v_cnum
	from schclasses
	where callnum = p_callnum;
	
	for eachRec in cDoubleEnroll loop
		if eachRec.snum = p_snum then
			p_answer := ' Student already enroll in other section';
		else
			p_answer := null;
		end if;
	end loop;
end;

		
-- 15HR Rules
procedure credit_cap(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_total number(2);
	v_add number;
begin
	select nvl(sum(crhr),0) into v_total
	from enrollments e, courses c, schclasses sc
	where e.snum = p_snum and c.cnum = sc.cnum
	and sc.callnum = e.callnum and sc.dept = c.dept;
	
	select count(crhr) into v_add
	from courses c, schclasses sc
	where sc.cnum = c.cnum and sc.callnum = p_callnum
	and sc.dept = c.dept;
	
	if v_total + v_add <= 15 then
		p_answer := null;
	else
		p_answer := 'Student can enroll max 15 credit hours per semester';
	end if;
end;


-- standing requirement
procedure standing(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_stand number;
	v_classStand number;
begin
--check student standing
	select standing into v_stand
	from students
	where snum = p_snum;
--check class standing requirement
	select standing into v_classStand
	from courses c, schclasses sc
	where c.cnum = sc.cnum and c.dept = sc.dept
	and sc.callnum = p_callnum;
	
	if v_stand < v_classStand then
		p_answer := 'Student not meet class standing requirement';
	else
		p_answer := null;
	end if;
end;


--disqualified student
procedure student_disqualified(
	p_snum students.snum%type,
	p_answer OUT varchar2) as
	
	v_standing number;
	v_gpa number;
begin
	select standing into v_standing
	from students
	where snum = p_snum;
	
	select gpa into v_gpa
	from students
	where snum = p_snum;
	
	if v_standing > 1 and v_gpa <2 then
		p_answer := 'Student  '||p_snum||'  is disqualified, cannot enroll in any course';
	else
		p_answer := null;
	end if;
end;


--Class Capacity
procedure course_cap(
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_cap number(3);
	v_count number;
	
begin
	select capacity into v_cap
	from schclasses
	where callnum = p_callnum;

	select count(callnum) into v_count
	from enrollments 
	where callnum = p_callnum and grade is null;
	
	if v_count < v_cap then
		p_answer := null;
	else
		p_answer := 'Class is full';
	end if;
end;


--waitlist
procedure proc_waitlist(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_count number;
	
begin
	select count(*) into v_count
	from waitlist
	where snum = p_snum and callnum = p_callnum;
	
	if v_count = 1 then
		p_answer := 'Student already in waitlist for this class';
	else
		insert into waitlist values (p_snum, p_callnum, sysdate);
		p_answer := 'Student ' || p_snum || ' is now on waitlist for '||p_callnum;
	end if;
end;


--procedure AddMe
procedure AddMe(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_snum varchar2(1000);
	v_callnum varchar2(1000);
	v_error varchar2(1000);
	v_error_msg varchar2(1000);
	
begin
	v_snum := valid_snum(p_snum);
	v_callnum := valid_callnum(p_callnum);
	if v_snum is null and v_callnum is null then
		repeat_enrollment(p_snum, p_callnum, v_error_msg);
		v_error := v_error_msg;
		if v_error is null then
			double_enrollment(p_snum, p_callnum, v_error_msg);
			v_error := v_error || v_error_msg;
			if v_error is null then
				credit_cap(p_snum, p_callnum, v_error_msg);
				v_error := v_error || v_error_msg;
				if v_error is null then
					standing(p_snum, p_callnum, v_error_msg);
					v_error := v_error || v_error_msg;
					if v_error is null then
						student_disqualified(p_snum, v_error_msg);
						v_error := v_error || v_error_msg;
						if v_error is null then
							course_cap(p_callnum, v_error_msg);
							v_error := v_error || v_error_msg;
							if v_error is null then
								insert into enrollments values (p_snum, p_callnum, null);
								dbms_output.put_line('Student  '||p_snum||'  successfully add');
							else			
								proc_waitlist(p_snum,p_callnum,v_error_msg);
								v_error := v_error  || v_error_msg;
								dbms_output.put_line(v_error);										
							end if;
						else
							dbms_output.put_line (v_error);
						end if;
					else
						dbms_output.put_line (v_error);
					end if;
				else
					dbms_output.put_line(v_error);
				end if;
			else
				dbms_output.put_line(v_error);
			end if;
		else
			dbms_output.put_line(v_error);
		end if;
	else
		dbms_output.put_line(v_snum);
		dbms_output.put_line(v_callnum);
	end if;
end;

--Not Enrolled
procedure check_enroll(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_count number;
begin
	select count(*) into v_count
	from enrollments
	where snum = p_snum and callnum = p_callnum;
	
	if v_count = 1 then
		p_answer := null;
	else
		p_answer := 'Cannot drop, student is not enrolled in this class';
	end if;
end;

--already graded
procedure check_grade(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_grade varchar2(2);
begin
	select grade into v_grade
	from enrollments
	where snum = p_snum and callnum = p_callnum;
	
	if v_grade is null then
		p_answer := null;
	else
		p_answer := 'Cannot drop, student already got graded';
	end if;
end;


--Give student W
procedure gradeW(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
begin
	update enrollments	
	set grade = 'W'
	where snum = p_snum and callnum = p_callnum;
	
	p_answer :=  ('Student  '||p_snum||'  is drop with a W');
	
end;

--check waitlist to add in class
procedure waitlistAdd(
	p_callnum schclasses.callnum%type,
	p_answer OUT varchar2) as
	
	v_error varchar2(1000);
	v_snum students.snum%type;
	v_callnum schclasses.callnum%type;
	v_check number(2);
	
	cursor CwaitlistAdd is
		select snum, callnum 
		from waitlist
		where callnum= p_callnum
		order by time;
begin
	open CwaitlistAdd;
	loop
		fetch CwaitlistAdd into v_snum, v_callnum;
		exit when CwaitlistAdd%NOTFOUND;		
		Enroll.AddMe(v_snum, p_callnum,v_error);
		p_answer := v_error;
		
		select count(*) into v_check
		from enrollments
		where snum = v_snum and callnum = v_callnum;
		
		if v_check = 1 then
			--delete record after successfully add them in class
			delete from waitlist 
			where snum = v_snum and callnum = v_callnum;
			dbms_output.put_line('Student '|| v_snum||' enroll in  ' ||p_callnum||'is removed out of waitlist');
		else
			dbms_output.put_line('Student  '||v_snum|| ' cannot enroll');
		end if;
		
	end loop;
	close CwaitlistAdd;
end;


--DROP ME
procedure DropMe(
	p_snum students.snum%type,
	p_callnum schclasses.callnum%type) as
	
	v_snum varchar2(1000);
	v_callnum varchar2(1000);
	v_error varchar2(1000);
	v_error_msg varchar2(1000);
begin
	v_snum := valid_snum(p_snum);
	v_callnum := valid_callnum(p_callnum);
	if v_snum is null and v_callnum is null then
		check_enroll(p_snum,p_callnum,v_error_msg);
		v_error := v_error_msg;
		if v_error is null then
			check_grade(p_snum, p_callnum, v_error_msg);
			v_error := v_error || v_error_msg;
			if v_error is null then
				gradeW(p_snum, p_callnum, v_error_msg);
				v_error := v_error || v_error_msg;
				dbms_output.put_line(v_error);
				waitlistAdd(p_callnum, v_error_msg);
				dbms_output.put_line(v_error_msg);
			else
				dbms_output.put_line(v_error);
			end if;
		else
			dbms_output.put_line(v_error);
		end if;
	else
		dbms_output.put_line(v_snum);
		dbms_output.put_line(v_callnum);
	end if;
end;


end Enroll;
/

spool off;

	
	

--start C:\Users\dmuha\Desktop\IS480(Fall2018)\Project\setup.sql