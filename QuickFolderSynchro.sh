#! /bin/bash
# Este script sirve para actualizar un disco duro en otro
# Se le debe pasar la ubicacion del disco Origen y del disco Destino
# Para ello realiza los siguientes pasos :
# 0) Crear el directorio destino si no existe
# 1) Para cada directorio comprueba los archivos distintos de tipo directorio y si tienen contenido distinto del destino lo copia
# El contenido distinto lo estima a partir de los tamaños y de las fechas de modificación
# 2) Ver la lista de archivos normales y directorios distintos del Destino que no esten en Origen y eliminarlos
# 3) Para cada directorio Origen lanzar de forma recursiva el script

if test "$2" = ""; then
   echo "Argumentos incorrectos";
   exit 1
fi

confirmar="$3"
if test "$confirmar" != "No"; then
   echo -e "Confirma que $2 es correcto ? Conteste Yes para continuar No para cancelar \c"; read resp;   
   while test "$resp" != "Yes"; do 
      if test "$resp" = "No"; then
         exit 2;
      fi
      echo -e "Confirma que $2 es correcto ? Conteste Yes para continuar No para cancelar \c"; read resp;      
   done
fi

directorioOrigen="$1"
directorioDestino="$2"

#echo " Directorio ORIGEN : $1"
#echo " Directorio DESTINO : $2"

IFS='
'
archivosEncontrados=0;
archivosExistentesCopiados=0;
archivosNoExistentesCopiados=0;
archivosDestinoEncontrados=0;
archivosDestinoEliminados=0;

if [ ! -d "$1" ]; then
	# No existe el directorio origen $1
	echo "No existe el directorio destino $1"
	exit 1
fi

if [ ! -d "$2" ]; then
	# No existe el directorio destino $2
	if test "$confirmar" != "No"; then
		echo "No existe el directorio destino $2"
		exit 1
	else
		echo "No existe el directorio destino $2, se crea"
		if ! mkdir "$2"; then
			echo "No se ha podido crear el directorio destino $2"
			exit 1
		fi
	fi
fi

#echo "BUSCANDO ARCHIVOS EN $1"
# Se buscan los archivos en origen
for i in `echo "$1/*"`; do

	# Si no hay archivos se sale del bucle
	if [ "$i" = "$1/*" ]; then
		#echo "No hay archivos en $1"
		break;
	fi 
	
	# Para cada archivo ORIGEN se extrae el nombre y el tamaño y la fecha de modificación
	rutaOrigen="$i";
	nombreOrigen=${rutaOrigen##*/}
	tamanyoOrigen=`ls -l "$i" | cut -f5 -d" "`;
	fechaOrigen=`stat -c %Y "$i"`;
	
	# Los archivos con corchetes dan problemas por lo que se sustituyen por guiones
	nombreOrigenModificado=`echo $nombreOrigen | tr '[' '-' | tr ']' '-'`;
	if [ "$nombreOrigen" != "$nombreOrigenModificado" ] ; then
		echo "$1 -->  Nombre Archivo RENOVADO $nombreOrigenModificado"
		if ! mv "$1/$nombreOrigen" "$1/$nombreOrigenModificado"; then
			echo "ERROR: No ha podido renombrarse $1/$nombreOrigen"
		fi
	fi
	
	# A partir de aqui no hay que utilizar $i sino $1/$nombreOrigenModificado
	
	# Si el archivo no es un directorio
	if [ ! -d "$1/$nombreOrigenModificado" ]; then
		archivosEncontrados=$(( archivosEncontrados + 1  ));

		if [ -f "$2/$nombreOrigenModificado" ]; then
		
			tamanyoDestino=`ls -l "$2/$nombreOrigenModificado" | cut -f5 -d" "`;
			fechaDestino=`stat -c %Y "$2/$nombreOrigenModificado"`;
			
			# Si el archivo destino existe se comprueba si tiene el mismo contenido
	   		#if ! cmp "$i" "$2/$nombreOrigen" >/dev/null 2>/dev/null ; then
	   		# Se comprueba que tienen el mismo tamaño y fecha origen es anterior a fecha destino - es mas rapido que cmp
	   		if [ "$tamanyoOrigen" != "$tamanyoDestino" -o $fechaOrigen -gt $fechaDestino ]; then
	   			# Si los archivos no tienen el mismo contenido se copia el archivo
	   			archivosExistentesCopiados=$(( archivosExistentesCopiados + 1  )); 
	   			if [ "$tamanyoOrigen" != "$tamanyoDestino" ]; then
					echo "$1 --> $2/$nombreOrigenModificado EXISTE TAMAÑO DISTINTO, SE COPIA";
				else
					echo "$1 --> $2/$nombreOrigenModificado EXISTE FECHA ORIGEN POSTERIOR, SE COPIA";
				fi
				if ! cp "$1/$nombreOrigenModificado" "$2/$nombreOrigenModificado"; then
					echo "ERROR: No ha podido copiarse $1/$nombreOrigenModificado en $2"
				fi
			#else
				#echo "$1 --> $2/$nombreOrigenModificado EXISTE MISMO CONTENIDO, NO SE HACE NADA";
			fi
		else
			# Si no existe en destino se copia
			archivosNoExistentesCopiados=$(( archivosNoExistentesCopiados + 1  ));
			echo "$1 --> $2/$nombreOrigenModificado NO EXISTE, SE COPIA"
			if ! cp "$1/$nombreOrigenModificado" "$2/$nombreOrigenModificado"; then
				echo "ERROR: No ha podido copiarse $1/$nombreOrigenModificado en $2"
			fi
		fi
	fi
done

#echo  -e "\nESTADISTICAS $1 :"
#echo "$1 -> Archivos Encontrados : $archivosEncontrados"
#echo "$1 -> Archivos Existentes Copiados : $archivosExistentesCopiados"
#echo -e "$1 -> Archivos No Existentes Copiados : $archivosNoExistentesCopiados \n\n"

# Se recorre destino para eliminar los archivos que no existan en origen
#echo "BUSCANDO ARCHIVOS EN $2"
for j in `echo "$2/*"`; do

	# Caso que no hayan archivos se sale del bucle
	if [ "$j" = "$2/*" ]; then
		#echo "No hay archivos en $2"
		break;
	fi
	archivosDestinoEncontrados=$(( archivosDestinoEncontrados + 1  ));
	
	# Para cada archivo destino extraido el nombre
	rutaDestino="$j";
	nombreDestino=${rutaDestino##*/}
	archivoDestinoExisteEnOrigen=false;
	
	# Comprobamos si existe en Origen
	$(ls -l "$1/$nombreDestino" > /dev/null 2>/dev/null);
	if [ $? -eq 0 ]; then
		# El archivo existe en Origen
		archivoDestinoExisteEnOrigen=true
		#if [ -d "$j" ]; then
			#echo "$1 --> DIRECTORIO ENCONTRADO : $j EXISTE EN ORIGEN, NO SE HACE NADA"
		#else
			#echo "$1 --> ARCHIVO ENCONTRADO : $j EXISTE EN ORIGEN, NO SE HACE NADA"
		#fi
	fi

	# Si no existe el archivo en Destino se elimina, independientemente que sea un directorio o un fichero
	if [ $archivoDestinoExisteEnOrigen = "false" ]; then
		archivosDestinoEliminados=$(( archivosDestinoEliminados + 1  ));
		if [ -d "$j" ]; then
			echo "$1 --> DIRECTORIO ENCONTRADO : $j NO EXISTE EN ORIGEN, SE ELIMINA"
		else
			echo "$1 --> ARCHIVO ENCONTRADO : $j NO EXISTE EN ORIGEN, SE ELIMINA"
		fi
		if ! rm -fr $j; then
			echo "ERROR: No ha podido eliminarse $j de $2"
		fi
	fi
done

#echo -e "\nESTADISTICAS $2 :\n"
#echo "$1 -> Archivos Destino Encontrados : $archivosDestinoEncontrados"
#echo -e "$1 -> Archivos Destino Eliminados : $archivosDestinoEliminados\n\n"

# Recorremos el origen en busca de directorios
# El directorio existe en Destino, ya comprobado
for i in `echo "$1/*"`; do
	# Para cada archivo extraido el nombre y el tamaño
	rutaOrigen="$i";
	nombreOrigen=${rutaOrigen##*/}
	if [ -d "$i" ]; then
		#echo "$1 -->  DIRECTORIO ENCONTRADO : $i"
		# Se lanza el script para cada uno de los archivos
		#echo "$1 --> Lanzado el script $0 para el directorio $i y el destino $2/$nombreOrigen";
		if ! bash $0 "$i" "$2/$nombreOrigen" "No"; then
			echo "ERROR: No ha podido lanzarse bash $0 $i $2/$nombreOrigen"
		fi
	fi 
done




