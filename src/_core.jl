
# using Debug
using Memoize
using Compat

import Base.bytestring, Base.convert

if VERSION < v"0.4.0-dev+656"
	import Compat.isnull
else 
	import Base.isnull
end





# Return Values
const JNI_OK           = convert(Cint, 0)               #/* success */
const JNI_ERR          = convert(Cint, -1)              #/* unknown error */
const JNI_EDETACHED    = convert(Cint, -2)              #/* thread detached from the VM */
const JNI_EVERSION     = convert(Cint, -3)              #/* JNI version error */
const JNI_ENOMEM       = convert(Cint, -4)              #/* not enough memory */
const JNI_EEXIST       = convert(Cint, -5)              #/* VM already created */
const JNI_EINVAL       = convert(Cint, -6)              #/* invalid arguments */



include("types.jl")







function jnew(T::Symbol, argtypes::Tuple, args...) 
    sig = method_signature(Void, argtypes...)
    jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, metaclass(T), utf8("<init>"), sig)
    if (jmethodId == C_NULL) 
        error("No constructor for $T with signature $sig")
    end 
    return  _jcall(metaclass(T), jmethodId, jnifunc.NewObjectA, JavaObject{T}, argtypes, args...)
end

isnull(obj::JavaObject) = obj.ptr == C_NULL
isnull(obj::JClass) = obj.ptr == C_NULL




function geterror(allow=false)
	isexception = ccall(jnifunc.ExceptionCheck, jboolean, (Ptr{JNIEnv},), penv )

	if isexception == JNI_TRUE
	 	jclass = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv},Ptr{Uint8}), penv, "java/lang/Throwable")
		if jclass==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		jmethodId=ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, jclass, "toString", "()Ljava/lang/String;")
		if jmethodId==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		jthrow = ccall(jnifunc.ExceptionOccurred, Ptr{Void}, (Ptr{JNIEnv},), penv)
		if jthrow==C_NULL ; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		res = ccall(jnifunc.CallObjectMethod, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, jthrow, jmethodId)
		if res==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		msg = bytestring(JString(res))
		ccall(jnifunc.ExceptionDescribe, Void, (Ptr{JNIEnv},), penv ) #Print java stackstrace to stdout
		ccall(jnifunc.ExceptionClear, Void, (Ptr{JNIEnv},), penv )

		error(string("Error calling Java: ",msg))
	else
		if allow==false
			return #No exception pending, legitimate NULL returned from Java
		else
			error("Null from Java. Not known how")
		end
	end
end

if VERSION < v"0.4-"
	const unsafe_convert = Base.convert
else
	const unsafe_convert = Base.unsafe_convert
end
unsafe_convert(::Type{Ptr{Void}}, cls::JClass) = cls.ptr

# Call static methods
function jcall{T}(typ::Type{JavaObject{T}}, method::String, rettype::Type, argtypes::Tuple, args... )
	try
		gc_disable()
		sig = method_signature(rettype, argtypes...)

		jmethodId = ccall(jnifunc.GetStaticMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, metaclass(T), utf8(method), sig)
		if jmethodId==C_NULL; geterror(true); end

		_jcall(metaclass(T), jmethodId, C_NULL, rettype, argtypes, args...)
	finally
		gc_enable()
	end

end

# Call instance methods
function jcall(obj::JavaObject, method::String, rettype::Type, argtypes::Tuple, args... )
	try
		gc_disable()
		sig = method_signature(rettype, argtypes...)
		jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, metaclass(obj), utf8(method), sig)
		if jmethodId==C_NULL; geterror(true); end
		_jcall(obj, jmethodId, C_NULL, rettype,  argtypes, args...)
	finally
		gc_enable();
	end
end



#Generate these methods to satisfy ccall's compile time constant requirement
#_jcall for primitive and Void return types
for (x, y, z) in [ (:jboolean, :(jnifunc.CallBooleanMethodA), :(jnifunc.CallStaticBooleanMethodA)),
                  (:jchar, :(jnifunc.CallCharMethodA), :(jnifunc.CallStaticCharMethodA)),
                  (:jbyte, :(jnifunc.CallByteMethodA), :(jnifunc.CallStaticByteMethodA)),
                  (:jshort, :(jnifunc.CallShortMethodA), :(jnifunc.CallStaticShortMethodA)),
                  (:jint, :(jnifunc.CallIntMethodA), :(jnifunc.CallStaticIntMethodA)), 
                  (:jlong, :(jnifunc.CallLongMethodA), :(jnifunc.CallStaticLongMethodA)),
                  (:jfloat, :(jnifunc.CallFloatMethodA), :(jnifunc.CallStaticFloatMethodA)),
                  (:jdouble, :(jnifunc.CallDoubleMethodA), :(jnifunc.CallStaticDoubleMethodA)),
                  (:Void, :(jnifunc.CallVoidMethodA), :(jnifunc.CallStaticVoidMethodA)) ]
    m = quote
        function _jcall(obj,  jmethodId::Ptr{Void}, callmethod::Ptr{Void}, rettype::Type{$(x)}, argtypes::Tuple, args... ) 
            if callmethod == C_NULL #!
                callmethod = ifelse( typeof(obj)<:JavaObject, $y , $z )
            end
            @assert callmethod != C_NULL
            @assert jmethodId != C_NULL
            if(isnull(obj)); error("Attempt to call method on Java NULL"); end
            savedArgs, convertedArgs = convert_args(argtypes, args...)
            result = ccall(callmethod, $x , (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, convertedArgs)
            if result==C_NULL; geterror(); end
            if result == nothing; return; end
            return convert_result(rettype, result)
        end
    end
    eval(m)
end

#_jcall for Object return types
#obj -- reciever - Class pointer or object prointer
#jmethodId -- Java method ID
#callmethod -- the C method pointer to call
function _jcall(obj,  jmethodId::Ptr{Void}, callmethod::Ptr{Void}, rettype::Type, argtypes::Tuple, args... ) 
    if callmethod == C_NULL
        callmethod = ifelse( typeof(obj)<:JavaObject, jnifunc.CallObjectMethodA , jnifunc.CallStaticObjectMethodA )
    end
    @assert callmethod != C_NULL
    @assert jmethodId != C_NULL
    if(isnull(obj)); error("Attempt to call method on Java NULL"); end
    savedArgs, convertedArgs = convert_args(argtypes, args...)
    result = ccall(callmethod, Ptr{Void} , (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, convertedArgs)
    if result==C_NULL; geterror(); end
    return convert_result(rettype, result)
end

# jvalue(v::Integer) = int64(v) << (64-8*sizeof(v))
jvalue(v::Integer) = @compat Int64(v)
jvalue(v::Float32) = jvalue(reinterpret(Int32, v))
jvalue(v::Float64) = jvalue(reinterpret(Int64, v))
jvalue(v::Ptr) = jvalue(@compat Int(v))

# Get the JNI/C type for a particular Java type
function real_jtype(rettype)
	if issubtype(rettype, JavaObject) || issubtype(rettype, Array) || issubtype(rettype, JClass)
		jnitype = Ptr{Void}
	else 
		jnitype = rettype
	end
	return jnitype
end


function convert_args(argtypes::Tuple, args...)
	convertedArgs = Array(Int64, length(args))
	savedArgs = Array(Any, length(args))
	for i in 1:length(args)
		r = convert_arg(argtypes[i], args[i])
		savedArgs[i] = r[1]
		convertedArgs[i] = jvalue(r[2])
	end
	return savedArgs, convertedArgs
end

function convert_arg(argtype::Type{JString}, arg) 
	x = convert(JString, arg)
	return x, x.ptr
end

function convert_arg(argtype::Type, arg) 
	x = convert(argtype, arg)
	return x,x
end
function convert_arg{T<:JavaObject}(argtype::Type{T}, arg) 
    x = convert(T, arg)::T
    return x, x.ptr
end

for (x, y, z) in [ (:jboolean, :(jnifunc.NewBooleanArray), :(jnifunc.SetBooleanArrayRegion)),
                  (:jchar, :(jnifunc.NewCharArray), :(jnifunc.SetCharArrayRegion)),
                  (:jbyte, :(jnifunc.NewByteArray), :(jnifunc.SetByteArrayRegion)),
                  (:jshort, :(jnifunc.NewShortArray), :(jnifunc.SetShortArrayRegion)),
                  (:jint, :(jnifunc.NewIntArray), :(jnifunc.SetShortArrayRegion)), 
                  (:jlong, :(jnifunc.NewLongArray), :(jnifunc.SetLongArrayRegion)),
                  (:jfloat, :(jnifunc.NewFloatArray), :(jnifunc.SetFloatArrayRegion)),
                  (:jdouble, :(jnifunc.NewDoubleArray), :(jnifunc.SetDoubleArrayRegion)) ]
 	m = quote 
  		function convert_arg(argtype::Type{Array{$x,1}}, arg)
			carg = convert(argtype, arg)
			sz=length(carg)
			arrayptr = ccall($y, Ptr{Void}, (Ptr{JNIEnv}, jint), penv, sz)
			ccall($z, Void, (Ptr{JNIEnv}, Ptr{Void}, jint, jint, Ptr{$x}), penv, arrayptr, 0, sz, carg)
			return carg, arrayptr
		end
	end
	eval( m)
end

function convert_arg{T<:JavaObject}(argtype::Type{Array{T,1}}, arg)
	carg = convert(argtype, arg)
	sz=length(carg)
	init=carg[1]
	arrayptr = ccall(jnifunc.NewObjectArray, Ptr{Void}, (Ptr{JNIEnv}, jint, Ptr{Void}, Ptr{Void}), penv, sz, metaclass(T), init.ptr)
	for i=2:sz 
		ccall(jnifunc.SetObjectArrayElement, Void, (Ptr{JNIEnv}, Ptr{Void}, jint, Ptr{Void}), penv, arrayptr, i-1, carg[i].ptr)
	end
	return carg, arrayptr
end

convert_result{T<:JString}(rettype::Type{T}, result) = bytestring(JString(result))
convert_result{T<:JavaObject}(rettype::Type{T}, result) = T(result)
convert_result(rettype, result) = result

for (x, y, z) in [ (:jboolean, :(jnifunc.GetBooleanArrayElements), :(jnifunc.ReleaseBooleanArrayElements)),
                  (:jchar, :(jnifunc.GetCharArrayElements), :(jnifunc.ReleaseCharArrayElements)),
                  (:jbyte, :(jnifunc.GetByteArrayElements), :(jnifunc.ReleaseByteArrayElements)),
                  (:jshort, :(jnifunc.GetShortArrayElements), :(jnifunc.ReleaseShortArrayElements)),
                  (:jint, :(jnifunc.GetIntArrayElements), :(jnifunc.ReleaseIntArrayElements)), 
                  (:jlong, :(jnifunc.GetLongArrayElements), :(jnifunc.ReleaseLongArrayElements)),
                  (:jfloat, :(jnifunc.GetFloatArrayElements), :(jnifunc.ReleaseFloatArrayElements)),
                  (:jdouble, :(jnifunc.GetDoubleArrayElements), :(jnifunc.ReleaseDoubleArrayElements)) ]
	m=quote
		function convert_result(rettype::Type{Array{$(x),1}}, result)
			sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, result)
			arr = ccall($(y), Ptr{$(x)}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean} ), penv, result, C_NULL ) 
			jl_arr::Array = pointer_to_array(arr, (@compat Int(sz)), false)
			jl_arr = deepcopy(jl_arr)
			ccall($(z), Void, (Ptr{JNIEnv},Ptr{Void}, Ptr{$(x)}, jint), penv, result, arr, 0)  
			return jl_arr
		end
	end
	eval(m)
end

function convert_result{T}(rettype::Type{Array{JavaObject{T},1}}, result) 
	sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, result)

	ret = Array(JavaObject{T}, sz)

	for i=1:sz
		a=ccall(jnifunc.GetObjectArrayElement, Ptr{Void}, (Ptr{JNIEnv},Ptr{Void}, jint), penv, result, i-1)
		ret[i] = JavaObject{T}(a)
	end 
	return ret
end





@unix_only const sep = ":"
@windows_only const sep = ";"
cp=Array(String, 0)
opts=Array(String, 0)
addClassPath(s::String) = isloaded()?warn("JVM already initialised. This call has no effect"): push!(cp, s)
addOpts(s::String) = isloaded()?warn("JVM already initialised. This call has no effect"): push!(opts, s)




