export default function Notice({children,kind="info"}:{children:React.ReactNode;kind?:"info"|"error"|"success"}) {
 return <div className={`notice ${kind}`}>{children}</div>;
}