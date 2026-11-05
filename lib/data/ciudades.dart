/// Ciudades donde hay operación (las mismas de `CITIES` en la web) y la foto
/// representativa de cada una (`lib/ciudades.ts` de la web). Las fotos van
/// enlazadas a su sitio de origen: si una no carga, [FotoCiudad] cae a la de
/// respaldo o al fondo verde.
library;

const kCiudades = [
  'Villavicencio',
  'Acacías',
  'Restrepo',
  'Bogotá',
  'Medellín',
  'Cali',
  'Barranquilla',
  'Bucaramanga',
];

const kFotoCiudad = <String, String>{
  'Villavicencio':
      'https://maravillasdelguejar.com/wp-content/uploads/2025/10/Pueblos-cerca-a-Villavicencio-para-visitar.jpg',
  'Acacías': 'https://www.colombiaturismo.com.co/img/acacias-meta-colombia.jpg',
  'Cali':
      'https://www.cali.gov.co/info/caligovco_se/media/pubInt/thumbs/thpubInt_700X400_186322.webp',
  'Bucaramanga':
      'https://blog.redbus.co/wp-content/uploads/2018/06/Proyecto-nuevo-2025-02-28T151508.383.jpg',
  'Restrepo':
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcToPKTyyngReVY6fruHyFUtg1tXyR6Ny3kwa_wU2uuJTTk4uXomXskJrkw&s=10',
  'Bogotá':
      'https://cdn1.matadornetwork.com/blogs/2/2016/02/Bogota-Colombia-cityscape-1200x853.jpeg',
  'Medellín':
      'https://cdn.forbes.co/2020/09/Medell%C3%ADn-foto-ProColombia.jpg',
  'Barranquilla':
      'https://www.semana.com/resizer/v2/BATZAH5PDZHTJEX7LDBHQMMQMI.jpg?auth=11b49f69af6153b773529b1cb27e2ec0df3b0f29c251d4a22d9b2aca59ff2679',
};
